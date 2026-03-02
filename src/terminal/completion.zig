//! Command completion system with inline preview and menu selection
//!
//! This module provides intelligent command completion that works with
//! the HistoryManager to provide context-aware suggestions.

const std = @import("std");
const Allocator = std.mem.Allocator;
const HistoryManager = @import("history_manager.zig").HistoryManager;

/// Command completion system
pub const Completion = struct {
    allocator: Allocator,
    config: Config,

    /// Current input buffer (what the user has typed)
    input_buffer: std.ArrayList(u8),

    /// Current completion state
    state: State,

    /// Completion candidates (owned by this Completion)
    candidates: std.ArrayList(Candidate),

    /// Currently selected candidate index (null = use first)
    selected_index: ?usize,

    /// Configuration for the completion system
    pub const Config = struct {
        /// Maximum number of candidates to show
        max_candidates: usize = 10,

        /// Minimum characters before triggering completion
        min_chars: usize = 1,

        /// Completion mode
        mode: Mode = .menu,

        pub const Mode = enum {
            /// Inline preview only
            @"inline",

            /// Inline preview + selection menu
            menu,

            /// Disabled
            disabled,
        };
    };

    /// Completion state machine
    pub const State = enum {
        /// No completion active
        idle,

        /// Showing inline preview only
        inline_preview,

        /// Showing candidate menu
        menu_visible,
    };

    /// A completion candidate
    pub const Candidate = struct {
        /// The full command
        command: []const u8,

        /// Execution frequency
        frequency: usize,

        /// Relevance score
        score: f64,
    };

    /// Event result from handleKey
    pub const Event = union(enum) {
        /// Bytes to send to the PTY (empty if consumed)
        input_bytes: []const u8,

        /// Command was submitted (enter key)
        command_submitted: []const u8,

        /// Completion was accepted (tab key)
        completion_accepted: []const u8,
    };

    /// Initialize a new completion system
    pub fn init(allocator: Allocator, config: Config) Completion {
        return .{
            .allocator = allocator,
            .config = config,
            .input_buffer = std.ArrayList(u8).empty,
            .state = .idle,
            .candidates = std.ArrayList(Candidate).empty,
            .selected_index = null,
        };
    }

    /// Deinitialize and free resources
    pub fn deinit(self: *Completion) void {
        self.input_buffer.deinit(self.allocator);
        self.clearCandidates();
        self.candidates.deinit(self.allocator);
    }

    /// Handle a character input
    pub fn handleChar(
        self: *Completion,
        ch: u8,
        history: *const HistoryManager,
        current_path: ?[]const u8,
    ) !Event {
        // Add character to input buffer
        try self.input_buffer.append(self.allocator, ch);

        // Update completions
        try self.updateCompletions(history, current_path);

        // Return the character to be sent to PTY
        return .{ .input_bytes = &[_]u8{ch} };
    }

    /// Handle a special key
    pub const Key = enum {
        tab,
        up,
        down,
        escape,
        backspace,
        enter,
    };

    pub fn handleKey(
        self: *Completion,
        key: Key,
        history: *const HistoryManager,
        current_path: ?[]const u8,
    ) !?Event {
        return switch (key) {
            .tab => self.handleTab(history, current_path),
            .up => self.handleUp(),
            .down => self.handleDown(),
            .escape => self.handleEscape(),
            .backspace => self.handleBackspace(history, current_path),
            .enter => self.handleEnter(),
        };
    }

    /// Get the current completion text (the part to show in gray)
    pub fn getCurrentCompletion(self: *const Completion) ?[]const u8 {
        if (self.candidates.items.len == 0) return null;

        const idx = self.selected_index orelse 0;
        if (idx >= self.candidates.items.len) return null;

        const candidate = &self.candidates.items[idx];
        const prefix = self.input_buffer.items;

        // Return the suffix part only
        if (std.mem.startsWith(u8, candidate.command, prefix)) {
            return candidate.command[prefix.len..];
        }

        return null;
    }

    /// Get all current candidates
    pub fn getCandidates(self: *const Completion) []const Candidate {
        return self.candidates.items;
    }

    /// Get current selected index
    pub fn getSelectedIndex(self: *const Completion) ?usize {
        return self.selected_index;
    }

    /// Get current input prefix
    pub fn inputPrefix(self: *const Completion) []const u8 {
        return self.input_buffer.items;
    }

    /// Check if menu is currently visible
    pub fn isMenuVisible(self: *const Completion) bool {
        return self.state == .menu_visible;
    }

    /// Reset the completion state
    pub fn reset(self: *Completion) void {
        self.input_buffer.clearRetainingCapacity();
        self.state = .idle;
        self.clearCandidates();
        self.selected_index = null;
    }

    // Private methods

    fn handleTab(
        self: *Completion,
        history: *const HistoryManager,
        current_path: ?[]const u8,
    ) !?Event {
        // If we have candidates, accept the current selection
        if (self.candidates.items.len > 0) {
            const idx = self.selected_index orelse 0;
            if (idx < self.candidates.items.len) {
                const candidate = &self.candidates.items[idx];
                const command = candidate.command;

                // Clear current input and replace with full command
                self.input_buffer.clearRetainingCapacity();
                try self.input_buffer.appendSlice(command);

                // Record to history
                try history.recordCommand(current_path, command);

                // Return the full command minus what was already sent
                const result = try self.allocator.dupe(u8, command);
                return .{ .completion_accepted = result };
            }
        }

        // No candidates, just send tab to PTY
        return .{ .input_bytes = &[_]u8{ '\t' } };
    }

    fn handleUp(self: *Completion) !?Event {
        if (self.candidates.items.len == 0) {
            // No candidates, send up to PTY
            return null;
        }

        // Enter or navigate menu
        if (self.state != .menu_visible) {
            self.state = .menu_visible;
            self.selected_index = 0;
        } else {
            self.moveSelection(-1);
        }

        // Key is consumed
        return .{ .input_bytes = &[_]u8{} };
    }

    fn handleDown(self: *Completion) !?Event {
        if (self.candidates.items.len == 0) {
            // No candidates, send down to PTY
            return null;
        }

        // Enter or navigate menu
        if (self.state != .menu_visible) {
            self.state = .menu_visible;
            self.selected_index = 0;
        } else {
            self.moveSelection(1);
        }

        // Key is consumed
        return .{ .input_bytes = &[_]u8{} };
    }

    fn handleEscape(self: *Completion) !?Event {
        // Cancel completion, return to idle
        self.state = .idle;
        self.selected_index = null;
        return .{ .input_bytes = &[_]u8{} };
    }

    fn handleBackspace(
        self: *Completion,
        history: *const HistoryManager,
        current_path: ?[]const u8,
    ) !?Event {
        if (self.input_buffer.popOrNull() == null) {
            // Buffer is empty, send backspace to PTY
            return .{ .input_bytes = &[_]u8{127} }; // DEL
        }

        // Update completions after removing character
        try self.updateCompletions(history, current_path);

        // Still send backspace to PTY
        return .{ .input_bytes = &[_]u8{127} };
    }

    fn handleEnter(self: *Completion) !?Event {
        // Submit current input
        const input = try self.input_buffer.toOwnedSlice();
        self.reset();

        return .{ .command_submitted = input };
    }

    fn updateCompletions(
        self: *Completion,
        history: *const HistoryManager,
        current_path: ?[]const u8,
    ) !void {
        // Clear previous candidates
        self.clearCandidates();

        const prefix = self.input_buffer.items;

        // Check minimum length
        if (prefix.len < self.config.min_chars) {
            self.state = .idle;
            self.selected_index = null;
            return;
        }

        // Get new candidates
        const completions = try history.getCompletions(
            current_path,
            prefix,
            self.config.max_candidates,
            self.allocator,
        );

        // Transfer ownership
        for (completions) |c| {
            try self.candidates.append(self.allocator, .{
                .command = c.command,
                .frequency = c.frequency,
                .score = c.score,
            });
        }

        // Update state based on mode and candidates
        if (self.candidates.items.len > 0) {
            self.state = switch (self.config.mode) {
                .@"inline" => .inline_preview,
                .menu => .inline_preview, // Start with inline, menu on arrow key
                .disabled => .idle,
            };
            if (self.selected_index == null) {
                self.selected_index = 0;
            }
        } else {
            self.state = .idle;
            self.selected_index = null;
        }
    }

    fn moveSelection(self: *Completion, delta: i32) void {
        if (self.candidates.items.len == 0) return;

        const count = @as(i32, @intCast(self.candidates.items.len));
        const current = @as(i32, @intCast(self.selected_index orelse 0));

        var new_idx = current + delta;

        // Wrap around
        if (new_idx < 0) {
            new_idx = count - 1;
        } else if (new_idx >= count) {
            new_idx = 0;
        }

        self.selected_index = @intCast(new_idx);
    }

    fn clearCandidates(self: *Completion) void {
        for (self.candidates.items) |*candidate| {
            self.allocator.free(candidate.command);
        }
        self.candidates.clearRetainingCapacity();
    }
};
