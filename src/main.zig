const std = @import("std");
const platform = @import("platform/renderer.zig");
const GamePak = @import("core/gamepak.zig").GamePak;

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();

    const romPath = args.next() orelse {
        std.debug.print("Please use a valid rom: <rom.gba>\n", .{});
        return;
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var pak = GamePak.load(allocator, romPath) catch |err| {
        std.debug.print("Couldn't load rom: {}\n", .{err});
        return;
    };
    defer pak.deinit();

    const trimmed = std.mem.trimRight(u8, &pak.title, &[_]u8{ 0, ' ' });
    std.debug.print("Loaded: {s} ({d} bytes) \n", .{ trimmed, pak.rom.len });

    var renderer = platform.Renderer.init();
    defer renderer.deinit();

    while (platform.Renderer.processEvents()) {
        renderer.present();
    }
}
