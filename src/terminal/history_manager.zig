//! Command history manager with per-directory frequency tracking
//!
//! This module provides intelligent command history management that groups
//! commands by working directory, enabling context-aware command completion.

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

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
            var iter = self.commands.iterator();
            while (iter.next()) |entry| {
                allocator.destroy(entry.key_ptr.*);
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
        var results = std.ArrayList(Completion).init(allocator);
        defer {
            for (results.items) |*item| {
                allocator.free(item.command);
            }
            results.deinit();
        }

        // Determine which history to use
        var source_history: *const CommandHistory = &self.global_history;

        if (self.config.enable_per_directory and path != null) {
            const normalized = try self.normalizePath(path.?);
            defer self.allocator.free(normalized);

            if (self.history_by_path.get(normalized)) |entry| {
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
            if (entry.value.* < self.config.min_frequency_threshold) continue;

            // Check prefix match (case-sensitive for commands)
            if (std.mem.startsWith(u8, entry.key_ptr.*, prefix)) {
                const score = self.calculateScore(entry.value.*, entry.key_ptr.*);

                try results.append(.{
                    .command = try allocator.dupe(u8, entry.key_ptr.*),
                    .frequency = entry.value.*,
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
    fn calculateScore(self: *const HistoryManager, frequency: usize, command: []const u8) f64 {
        // Base score is the frequency
        var score: f64 = @floatFromInt(frequency);

        // Apply small length penalty (shorter commands slightly preferred)
        const length_factor = 1.0 / @as(f64, @max(1, command.len));
        score *= (0.9 + 0.1 * length_factor);

        return score;
    }

    /// Normalize a path (resolve symlinks, . and ..)
    fn normalizePath(self: *const HistoryManager, path: []const u8) ![]const u8 {
        // Use a stack buffer for path resolution
        var buf: [4096]u8 = undefined;
        const resolved = std.fs.path.resolveZ(path, &buf) catch |err| switch (err) {
            error.NameTooLong => return error.PathTooLong,
            else => return err,
        };

        // Return a dupe of the resolved path
        return self.allocator.dupe(u8, resolved);
    }

    /// Prune history if it exceeds the maximum size
    fn pruneHistory(self: *const HistoryManager, history: *CommandHistory) !void {
        if (history.commands.count() <= self.config.max_history_size) return;

        // Collect all entries for sorting
        var entries = std.ArrayList(struct {
            command: []const u8,
            frequency: usize,
        }).init(self.allocator);

        defer {
            entries.deinit();
        }

        var iter = history.commands.iterator();
        while (iter.next()) |entry| {
            try entries.append(.{
                .command = entry.key_ptr.*,
                .frequency = entry.value.*,
            });
        }

        // Sort by frequency (ascending - to remove lowest first)
        std.sort.heap(@TypeOf(entries.items[0]), entries.items, {}, struct {
            fn lessThan(context: void, a: @TypeOf(entries.items[0]), b: @TypeOf(entries.items[0])) bool {
                _ = context;
                return a.frequency < b.frequency;
            }
        }.lessThan);

        // Remove the lowest frequency entries
        const to_remove = history.commands.count() - self.config.max_history_size;
        for (entries.items[0..to_remove]) |entry| {
            _ = history.commands.remove(entry.command);
            self.allocator.free(entry.command);
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
    };

    try testing.expectEqual(@as(usize, 2), completions.len);

    // git status should be first (higher frequency)
    try testing.expectEqualStrings("git status", completions[0].command);
    try testing.expectEqual(@as(usize, 2), completions[0].frequency);

    try testing.expectEqualStrings("git push", completions[1].command);
    try testing.expectEqual(@as(usize, 1), completions[1].frequency);
}
