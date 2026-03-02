//! OSC 711 - Command history tracking
//!
//! This OSC sequence is used by shell integration to report executed commands
//! for intelligent command completion.
//!
//! Format: ESC ] 711 ; <command> ST
//! Example: ESC ] 711 ; cd vscWork ST

const std = @import("std");
const Parser = @import("../../osc.zig").Parser;
const OSCCommand = @import("../../osc.zig").Command;

const log = std.log.scoped(.osc_command_history);

/// Parse OSC 711, command history
pub fn parse(parser: *Parser, _: ?u8) ?*OSCCommand {
    const writer = parser.writer orelse {
        parser.state = .invalid;
        return null;
    };
    const data = writer.buffered();

    // OSC 711 requires at least the command (can be empty)
    // The entire data is the command (may contain any characters except ST)
    // We need to make a copy of the command
    const allocator = parser.alloc orelse {
        log.warn("OSC 711: no allocator available", .{});
        parser.state = .invalid;
        return null;
    };

    const command = allocator.dupe(u8, data) catch |err| {
        log.warn("OSC 711: failed to allocate command: {}", .{err});
        parser.state = .invalid;
        return null;
    };

    parser.command = .{ .command_history = .{
        .command = command,
    } };

    return &parser.command;
}

test "OSC 711: simple command" {
    const testing = std.testing;
    const testing_allocator = testing.allocator;

    var p: Parser = .init(testing_allocator);
    defer p.deinit();

    const input = "711;cd vscWork";
    for (input) |ch| p.next(ch);

    const cmd = p.end(null).?.*;
    try testing.expect(cmd == .command_history);
    try testing.expectEqualStrings("cd vscWork", cmd.command_history.command);
    testing_allocator.free(cmd.command_history.command);
}

test "OSC 711: complex command with special chars" {
    const testing = std.testing;
    const testing_allocator = testing.allocator;

    var p: Parser = .init(testing_allocator);
    defer p.deinit();

    const input = "711;git commit -m \"fix: bug\"";
    for (input) |ch| p.next(ch);

    const cmd = p.end(null).?.*;
    try testing.expect(cmd == .command_history);
    try testing.expectEqualStrings("git commit -m \"fix: bug\"", cmd.command_history.command);
    testing_allocator.free(cmd.command_history.command);
}

test "OSC 711: empty command" {
    const testing = std.testing;
    const testing_allocator = testing.allocator;

    var p: Parser = .init(testing_allocator);
    defer p.deinit();

    const input = "711;";
    for (input) |ch| p.next(ch);

    // Empty command should still parse
    const cmd = p.end(null).?.*;
    try testing.expect(cmd == .command_history);
    try testing.expectEqualStrings("", cmd.command_history.command);
    testing_allocator.free(cmd.command_history.command);
}
