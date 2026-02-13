const std = @import("std");
const inputpkg = @import("../input.zig");
const state = &@import("../global.zig").state;
const c = @import("../main_c.zig");

const Config = @import("Config.zig");
const c_get = @import("c_get.zig");
const edit = @import("edit.zig");
const Key = @import("key.zig").Key;

const log = std.log.scoped(.config);

/// Create a new configuration filled with the initial default values.
export fn ghostty_config_new() ?*Config {
    const result = state.alloc.create(Config) catch |err| {
        log.err("error allocating config err={}", .{err});
        return null;
    };

    result.* = Config.default(state.alloc) catch |err| {
        log.err("error creating config err={}", .{err});
        state.alloc.destroy(result);
        return null;
    };

    return result;
}

export fn ghostty_config_free(ptr: ?*Config) void {
    if (ptr) |v| {
        v.deinit();
        state.alloc.destroy(v);
    }
}

/// Deep clone the configuration.
export fn ghostty_config_clone(self: *Config) ?*Config {
    const result = state.alloc.create(Config) catch |err| {
        log.err("error allocating config err={}", .{err});
        return null;
    };

    result.* = self.clone(state.alloc) catch |err| {
        log.err("error cloning config err={}", .{err});
        state.alloc.destroy(result);
        return null;
    };

    return result;
}

/// Load the configuration from the CLI args.
export fn ghostty_config_load_cli_args(self: *Config) void {
    self.loadCliArgs(state.alloc) catch |err| {
        log.err("error loading config err={}", .{err});
    };
}

/// Load the configuration from the default file locations. This
/// is usually done first. The default file locations are locations
/// such as the home directory.
export fn ghostty_config_load_default_files(self: *Config) void {
    self.loadDefaultFiles(state.alloc) catch |err| {
        log.err("error loading config err={}", .{err});
    };
}

/// Load the configuration from a specific file path.
/// The path must be null-terminated.
export fn ghostty_config_load_file(self: *Config, path: [*:0]const u8) void {
    const path_slice = std.mem.span(path);
    self.loadFile(state.alloc, path_slice) catch |err| {
        log.err("error loading config from file path={s} err={}", .{ path_slice, err });
    };
}

/// Load the configuration from the user-specified configuration
/// file locations in the previously loaded configuration. This will
/// recursively continue to load up to a built-in limit.
export fn ghostty_config_load_recursive_files(self: *Config) void {
    self.loadRecursiveFiles(state.alloc) catch |err| {
        log.err("error loading config err={}", .{err});
    };
}

export fn ghostty_config_finalize(self: *Config) void {
    self.finalize() catch |err| {
        log.err("error finalizing config err={}", .{err});
    };
}

export fn ghostty_config_get(
    self: *Config,
    ptr: *anyopaque,
    key_str: [*]const u8,
    len: usize,
) bool {
    @setEvalBranchQuota(10_000);
    const key = std.meta.stringToEnum(Key, key_str[0..len]) orelse return false;
    return c_get.get(self, key, ptr);
}

export fn ghostty_config_trigger(
    self: *Config,
    str: [*]const u8,
    len: usize,
) inputpkg.Binding.Trigger.C {
    return config_trigger_(self, str[0..len]) catch |err| err: {
        log.err("error finding trigger err={}", .{err});
        break :err .{};
    };
}

fn config_trigger_(
    self: *Config,
    str: []const u8,
) !inputpkg.Binding.Trigger.C {
    const action = try inputpkg.Binding.Action.parse(str);
    const trigger: inputpkg.Binding.Trigger = self.keybind.set.getTrigger(action) orelse .{};
    return trigger.cval();
}

export fn ghostty_config_diagnostics_count(self: *Config) u32 {
    return @intCast(self._diagnostics.items().len);
}

export fn ghostty_config_get_diagnostic(self: *Config, idx: u32) Diagnostic {
    const items = self._diagnostics.items();
    if (idx >= items.len) return .{};
    const message = self._diagnostics.precompute.messages.items[idx];
    return .{ .message = message.ptr };
}

export fn ghostty_config_open_path() c.String {
    const path = edit.openPath(state.alloc) catch |err| {
        log.err("error opening config in editor err={}", .{err});
        return .empty;
    };

    return .fromSlice(path);
}

/// Sync with ghostty_diagnostic_s
const Diagnostic = extern struct {
    message: [*:0]const u8 = "",
};

/// Configuration for tracking changes
const ConfigChanges = struct {
    allocator: std.mem.Allocator,
    changes: std.StringHashMap([]const u8),

    pub fn init(alloc: std.mem.Allocator) ConfigChanges {
        return .{
            .allocator = alloc,
            .changes = std.StringHashMap([]const u8).init(alloc),
        };
    }

    pub fn deinit(self: *ConfigChanges) void {
        var iter = self.changes.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.changes.deinit();
    }

    pub fn set(self: *ConfigChanges, key: []const u8, value: []const u8) !void {
        const copy = try self.allocator.dupeZ(u8, value);
        try self.changes.put(key, copy);
    }

    pub fn get(self: *const ConfigChanges, key: []const u8) ?[]const u8 {
        return self.changes.get(key);
    }
};

/// Set a configuration value by key and value string.
/// Returns true if successful, false otherwise.
export fn ghostty_config_set(
    self: *Config,
    key: [*:0]const u8,
    value: [*:0]const u8,
) bool {
    const key_slice = std.mem.span(key);
    const value_slice: ?[]const u8 = if (value[0] != 0) value[0..std.mem.len(value)] else null;

    // Create a line iterator to parse the value
    const LineIterator = struct {
        key: []const u8,
        value: ?[]const u8,
        consumed: bool = false,

        pub fn next(self: *LineIterator) ?[]const u8 {
            if (self.consumed) return null;
            self.consumed = true;

            // Format: key = value
            var buf: [512]u8 = undefined;
            var fba = std.io.fixedBufferStream(&buf);
            var writer = fba.writer();

            // Write key
            writer.writeAll(self.key) catch return null;

            // Write value if present
            if (self.value) |v| {
                writer.writeAll(" = ") catch return null;
                writer.writeAll(v) catch return null;
            }

            const written = writer.written();
            return written[0..];
        }
    };

    var iter = LineIterator{ .key = key_slice, .value = value_slice };
    self.loadIter(state.alloc, &iter) catch |err| {
        log.err("error setting config key={s} value={?s} err={}", .{ key_slice, value_slice, err });
        return false;
    };

    return true;
}

/// Save configuration to the default config file path.
/// Returns true if successful, false otherwise.
export fn ghostty_config_save(self: *Config, path: ?[*:0]const u8) bool {
    const config_path = if (path) |p| std.mem.span(p) else blk: {
        // Get default config path
        const edit = @import("edit.zig");
        break :blk edit.openPath(state.alloc) catch |err| {
            log.err("error getting config path err={}", .{err});
            return null;
        };
    };

    if (config_path) |cp| {
        // Ensure directory exists
        if (std.fs.path.dirname(cp)) |dir| {
            std.fs.cwd().makePath(dir) catch |err| {
                log.err("error creating config directory err={}", .{err});
                return false;
            };
        }

        // Write config to file
        var file = std.fs.createFileAbsolute(cp, .{}) catch |err| {
            log.err("error creating config file path={s} err={}", .{ cp, err });
            return false;
        };
        defer file.close();

        var buf: [4096]u8 = undefined;
        var file_writer = file.writer(&buf);
        const writer = &file_writer.interface;

        // Write all config fields to file
        // Note: This is a simplified version that writes basic key=value pairs
        // For a complete implementation, we'd need to iterate over all config fields
        // and format them properly.
        self.writeToFile(writer) catch |err| {
            log.err("error writing config file err={}", .{err});
            return false;
        };

        log.info("saved configuration to path={s}", .{cp});
        return true;
    };

    return false;
}

/// Get metadata about configuration categories and keys.
/// This is used by the GUI to build the settings interface.
export fn ghostty_config_meta() ?*const ConfigMeta {
    const meta = state.alloc.create(ConfigMeta) catch |err| {
        log.err("error allocating config meta err={}", .{err});
        return null;
    };

    meta.* = ConfigMeta.init(state.alloc) catch |err| {
        log.err("error initializing config meta err={}", .{err});
        state.alloc.destroy(meta);
        return null;
    };

    return meta;
}

/// Configuration metadata for GUI building
pub const ConfigMeta = struct {
    allocator: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !ConfigMeta {
        return .{ .allocator = alloc };
    }

    pub fn deinit(self: *const ConfigMeta) void {
        // Free any allocated memory
        _ = self;
    }

    /// Get all configuration categories
    pub fn getCategories(self: *const ConfigMeta) []const CategoryMeta {
        return comptime categories;
    }

    /// Get all keys for a specific category
    pub fn getKeysForCategory(self: *const ConfigMeta, category: []const u8) []const KeyMeta {
        // This would return all keys belonging to a category
        // For now, return empty slice
        return &.{};
    }

    const comptime categories = []const CategoryMeta{
        .{ .name = "appearance", .display = "外观", .icon = "paintbrush" },
        .{ .name = "font", .display = "字体", .icon = "textformat" },
        .{ .name = "colors", .display = "颜色", .icon = "palette" },
        .{ .name = "terminal", .display = "终端", .icon = "terminal" },
        .{ .name = "window", .display = "窗口", .icon = "macwindow" },
        .{ .name = "keybindings", .display = "键盘绑定", .icon = "command" },
        .{ .name = "advanced", .display = "高级", .icon = "gearshape" },
    };
};

pub const CategoryMeta = struct {
    name: []const u8,
    display: []const u8,
    icon: []const u8,
};

pub const KeyMeta = struct {
    key: []const u8,
    display: []const u8,
    description: []const u8,
    type: KeyType,
};

pub const KeyType = enum {
    string,
    number,
    boolean,
    color,
    font_family,
    keybinding,
};
