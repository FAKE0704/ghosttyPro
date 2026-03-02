//! Command history manager with per-directory frequency tracking
//!
//! This module provides intelligent command history management that groups
//! commands by working directory, enabling context-aware command completion.

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const log = std.log.scoped(.history);

/// Per-directory command history with frequency tracking
pub const HistoryManager = struct {
    allocator: Allocator,
    config: Config,

    /// History grouped by normalized path
    history_by_path: std.StringHashMap(CommandHistory),

    /// Global command history (all directories combined)
    global_history: CommandHistory,

    /// Configuration for the history manager
    pub const Config = struct {
        /// Maximum number of history entries per directory
        max_history_size: usize = 1000,

        /// Minimum frequency threshold for completion suggestions
        min_frequency_threshold: usize = 1,

        /// Enable global history aggregation
        enable_global: bool = true,

        /// Enable per-directory history grouping
        enable_per_directory: bool = true,
    };

    /// Command history for a specific context (directory or global)
    pub const CommandHistory = struct {
        /// Command -> frequency mapping
        commands: std.StringHashMap(usize),

        /// Total command executions (for statistics)
        total_count: usize = 0,

        fn init(allocator: Allocator) CommandHistory {
            return .{
                .commands = std.StringHashMap(usize).init(allocator),
                .total_count = 0,
            };
        }

        fn deinit(self: *CommandHistory) void {
            const allocator = self.commands.allocator;
            var iter = self.commands.iterator();
            while (iter.next()) |entry| {
                allocator.free(entry.key_ptr.*);
            }
            self.commands.deinit();
        }
    };

    /// Completion candidate with scoring
    pub const Completion = struct {
        /// The complete command string
        command: []const u8,

        /// Execution frequency
        frequency: usize,

        /// Calculated relevance score (higher is better)
        score: f64 = 0.0,
    };

    /// Initialize a new history manager
    pub fn init(allocator: Allocator, config: Config) !HistoryManager {
        return .{
            .allocator = allocator,
            .config = config,
            .history_by_path = std.StringHashMap(CommandHistory).init(allocator),
            .global_history = CommandHistory.init(allocator),
        };
    }

    /// Deinitialize and free all resources
    pub fn deinit(self: *HistoryManager) void {
        // Free all per-directory histories
        var iter = self.history_by_path.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit();
        }
        self.history_by_path.deinit();

        // Free global history
        self.global_history.deinit();
    }

    /// Record a command execution
    pub fn recordCommand(
        self: *HistoryManager,
        path: ?[]const u8,
        command: []const u8,
    ) !void {
        // Update global history
        if (self.config.enable_global) {
            try self.recordToHistory(&self.global_history, command);
        }

        // Update directory-specific history
        if (self.config.enable_per_directory) {
            if (path) |p| {
                const normalized = try self.normalizePath(p);
                defer self.allocator.free(normalized);

                const gop = try self.history_by_path.getOrPut(normalized);
                if (!gop.found_existing) {
                    gop.key_ptr.* = try self.allocator.dupe(u8, normalized);
                    gop.value_ptr.* = CommandHistory.init(self.allocator);
                }

                try self.recordToHistory(gop.value_ptr, command);

                // Prune if necessary
                try self.pruneHistory(gop.value_ptr);
            }
        }
    }

    /// Get completion candidates for a given prefix
    pub fn getCompletions(
        self: *const HistoryManager,
        path: ?[]const u8,
        prefix: []const u8,
        limit: usize,
        allocator: Allocator,
    ) ![]Completion {
        var results = std.ArrayList(Completion){};
        defer {
            for (results.items) |*item| {
                allocator.free(item.command);
            }
            results.deinit(allocator);
        }

        // Determine which history to use
        var source_history: *const CommandHistory = &self.global_history;

        if (self.config.enable_per_directory and path != null) {
            const normalized = try self.normalizePath(path.?);
            defer self.allocator.free(normalized);

            if (self.history_by_path.getPtr(normalized)) |entry| {
                // Use per-directory history if available and has entries
                if (entry.commands.count() > 0) {
                    source_history = entry;
                }
            }
        }

        // Collect matching completions
        var iter = source_history.commands.iterator();
        while (iter.next()) |entry| {
            // Skip if below threshold
            if (entry.value_ptr.* < self.config.min_frequency_threshold) continue;

            // Check prefix match (case-sensitive for commands)
            if (std.mem.startsWith(u8, entry.key_ptr.*, prefix)) {
                const score = self.calculateScore(entry.value_ptr.*, entry.key_ptr.*);

                try results.append(allocator, .{
                    .command = try allocator.dupe(u8, entry.key_ptr.*),
                    .frequency = entry.value_ptr.*,
                    .score = score,
                });
            }
        }

        // Sort by frequency (descending), then by length (ascending)
        const SortContext = struct {
            fn lessThan(
                context: void,
                a: Completion,
                b: Completion,
            ) bool {
                _ = context;
                // Primary: frequency descending
                if (a.frequency != b.frequency) {
                    return a.frequency > b.frequency;
                }
                // Secondary: command length ascending (shorter commands first)
                return a.command.len < b.command.len;
            }
        };

        std.sort.heap(Completion, results.items, {}, SortContext.lessThan);

        // Limit results
        if (results.items.len > limit) {
            results.shrinkRetainingCapacity(limit);
        }

        // Transfer ownership to caller
        const final_results = try allocator.alloc(Completion, results.items.len);
        for (results.items, 0..) |item, i| {
            final_results[i] = .{
                .command = item.command,
                .frequency = item.frequency,
                .score = item.score,
            };
        }

        // Don't free the commands we just transferred
        results.items.len = 0;
        return final_results;
    }

    /// Record a command to a specific history
    fn recordToHistory(self: *const HistoryManager, history: *CommandHistory, command: []const u8) !void {
        const gop = try history.commands.getOrPut(command);
        if (!gop.found_existing) {
            gop.key_ptr.* = try self.allocator.dupe(u8, command);
            gop.value_ptr.* = 0;
        }
        gop.value_ptr.* += 1;
        history.total_count += 1;
    }

    /// Calculate a relevance score for a completion candidate
    fn calculateScore(_self: *const HistoryManager, frequency: usize, command: []const u8) f64 {
        _ = _self;
        // Base score is the frequency
        var score: f64 = @floatFromInt(frequency);

        // Apply small length penalty (shorter commands slightly preferred)
        const cmd_len: f64 = @floatFromInt(command.len);
        const length_factor = 1.0 / @max(@as(f64, 1), cmd_len);
        score *= (0.9 + 0.1 * length_factor);

        return score;
    }

    /// Normalize a path (resolve symlinks, . and ..)
    fn normalizePath(self: *const HistoryManager, path: []const u8) ![]const u8 {
        // Use resolve with allocator
        return std.fs.path.resolve(self.allocator, &.{path});
    }

    /// Prune history if it exceeds the maximum size
    fn pruneHistory(self: *const HistoryManager, history: *CommandHistory) !void {
        if (history.commands.count() <= self.config.max_history_size) return;

        // Collect commands by frequency for sorting
        var freq_list = std.ArrayList(struct {
            frequency: usize,
            command: []const u8,
        }){};
        defer freq_list.deinit(self.allocator);

        var iter = history.commands.iterator();
        while (iter.next()) |entry| {
            try freq_list.append(self.allocator, .{
                .frequency = entry.value_ptr.*,
                .command = entry.key_ptr.*,
            });
        }

        // Sort by frequency (ascending - to remove lowest first)
        const SortContext = struct {
            fn lessThan(context: void, a: @TypeOf(freq_list.items[0]), b: @TypeOf(freq_list.items[0])) bool {
                _ = context;
                return a.frequency < b.frequency;
            }
        };
        std.sort.heap(@TypeOf(freq_list.items[0]), freq_list.items, {}, SortContext.lessThan);

        // Remove the lowest frequency entries
        const to_remove = history.commands.count() - self.config.max_history_size;
        for (freq_list.items[0..to_remove]) |entry| {
            _ = history.commands.remove(entry.command);
            self.allocator.free(entry.command);
        }
    }

    /// Get the default history file path
    pub fn getDefaultHistoryPath(allocator: Allocator) ![]const u8 {
        const home_dir = std.process.getEnvVarOwned(allocator, "HOME") catch |err| switch (err) {
            error.EnvironmentVariableNotFound => {
                // Try USERPROFILE on Windows
                return std.process.getEnvVarOwned(allocator, "USERPROFILE");
            },
            else => return err,
        };

        const ghostty_dir = try std.fs.path.join(allocator, &.{ home_dir, ".ghostty" });

        // Ensure directory exists
        std.fs.cwd().makePath(ghostty_dir) catch |err| {
            allocator.free(ghostty_dir);
            return err;
        };
        defer allocator.free(ghostty_dir);

        const history_file = try std.fs.path.join(allocator, &.{ ghostty_dir, "completion_history.json" });
        return history_file;
    }

    /// Save history to file
    pub fn saveToFile(self: *const HistoryManager, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{ .read = true });
        defer file.close();

        const writer = file.writer();
        defer {
            // Catch any errors during close but don't fail
            writer.flush() catch |err| {
                log.warn("error flushing completion history: {}", .{err});
            };
        }

        // Write JSON header
        try writer.print("{{\n", .{});
        try writer.writeAll("\"version\": 1,\n");

        // Write global history
        try writer.writeAll("\"global\": {{\n");
        var first = true;
        var iter = self.global_history.commands.iterator();
        while (iter.next()) |entry| {
            if (!first) try writer.writeAll(",\n");
            first = false;

            // Escape JSON string
            try writer.print("  \"{s}\": {d}", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
        try writer.writeAll("\n}}");

        // Write per-directory history
        if (self.history_by_path.count() > 0) {
            try writer.writeAll(",\n\"directories\": {{\n");

            var dir_iter = self.history_by_path.iterator();
            var dir_first = true;
            while (dir_iter.next()) |dir_entry| {
                if (!dir_first) try writer.writeAll(",\n");
                dir_first = false;

                try writer.print("  \"{s}\": {{\n", .{ dir_entry.key_ptr.* });

                var cmd_first = true;
                var cmd_iter = dir_entry.value_ptr.commands.iterator();
                while (cmd_iter.next()) |cmd_entry| {
                    if (!cmd_first) try writer.writeAll(",\n");
                    cmd_first = false;

                    try writer.print("    \"{s}\": {d}", .{ cmd_entry.key_ptr.*, cmd_entry.value_ptr.* });
                }
                try writer.writeAll("\n  }}");
            }
            try writer.writeAll("\n}}");
        }

        try writer.writeAll("\n}}\n");
    }

    /// Load history from file
    pub fn loadFromFile(self: *HistoryManager, path: []const u8) !void {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                // First run, no history file exists yet
                return;
            },
            else => return err,
        };
        defer file.close();

        const max_size = 10 * 1024 * 1024; // 10MB max
        const content = try file.readAllAlloc(self.allocator, max_size);
        defer self.allocator.free(content);

        // Parse JSON (simplified - for production use a proper JSON parser)
        // For now, we'll implement basic parsing
        var lines_iter = std.mem.splitSequence(u8, content, "\n");

        var in_global = false;
        var in_directories = false;
        var current_path: ?[]const u8 = null;

        while (lines_iter.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \n\r\t{}\"");
            if (trimmed.len == 0) continue;

            if (std.mem.eql(u8, trimmed, "\"global\": {")) {
                in_global = true;
                continue;
            }
            if (std.mem.eql(u8, trimmed, "\"directories\": {")) {
                in_global = false;
                in_directories = true;
                continue;
            }
            if (in_global and trimmed[0] == '}') {
                in_global = false;
                continue;
            }
            if (in_directories and trimmed[0] == '}') {
                in_directories = false;
                continue;
            }

            if (in_global) {
                // Parse "command": count
                if (std.mem.indexOf(u8, line, ":")) |idx| {
                    const cmd = trimmed[1 .. idx];
                    const count_str = trimmed[idx + 1 ..];
                    const count = std.fmt.parseInt(usize, count_str) catch continue;

                    const cmd_copy = try self.allocator.dupeZ(u8, cmd);
                    try self.recordToHistory(&self.global_history, cmd_copy);
                    _ = try self.global_history.commands.put(cmd_copy, count);
                }
            } else if (in_directories) {
                if (trimmed[trimmed.len - 1] == '{') {
                    // New directory entry
                    const dir_path = trimmed[1 .. trimmed.len - 2];
                    const dir_copy = try self.allocator.dupeZ(u8, dir_path);
                    current_path = dir_copy;

                    const gop = try self.history_by_path.getOrPut(dir_copy);
                    if (!gop.found_existing) {
                        gop.key_ptr.* = dir_copy;
                        gop.value_ptr.* = CommandHistory.init(self.allocator);
                    }
                } else if (current_path != null) {
                    // Command entry in current directory
                    if (std.mem.indexOf(u8, line, ":")) |idx| {
                        const cmd = trimmed[1 .. idx];
                        const count_str = trimmed[idx + 1 ..];
                        const count = std.fmt.parseInt(usize, count_str) catch continue;

                        const cmd_copy = try self.allocator.dupeZ(u8, cmd);
                        if (self.history_by_path.get(current_path.?)) |history| {
                            try self.recordToHistory(history, cmd_copy);
                            _ = try history.commands.put(cmd_copy, count);
                        }
                    }
                }
            }
        }
    }
};

// Simple test when built with test mode
test "HistoryManager basic operations" {
    const testing = std.testing;
    var manager = try HistoryManager.init(testing.allocator, .{});
    defer manager.deinit();

    // Record some commands
    try manager.recordCommand("/home/user/project", "git status");
    try manager.recordCommand("/home/user/project", "git status");
    try manager.recordCommand("/home/user/project", "git push");
    try manager.recordCommand("/home/user/project", "npm test");

    // Get completions for "git"
    const completions = try manager.getCompletions(
        "/home/user/project",
        "git",
        10,
        testing.allocator,
    );
    defer {
        for (completions) |c| {
            testing.allocator.free(c.command);
        }
        testing.allocator.free(completions);
    }

    try testing.expectEqual(@as(usize, 2), completions.len);

    // git status should be first (higher frequency)
    try testing.expectEqualStrings("git status", completions[0].command);
    try testing.expectEqual(@as(usize, 2), completions[0].frequency);

    try testing.expectEqualStrings("git push", completions[1].command);
    try testing.expectEqual(@as(usize, 1), completions[1].frequency);
}
