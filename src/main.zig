const std = @import("std");
const platform = @import("platform/renderer.zig");
const Gba = @import("core/gba.zig").Gba;

test {
    _ = @import("core/bus.zig");
    // Voeg hier toekomstige modules toe:
    // _ = @import("core/cpu.zig");
    // _ = @import("core/arm.zig");
}

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

    var gba = try Gba.init(allocator, romPath);
    defer gba.deinit();

    const trimmed = std.mem.trimRight(u8, &gba.gamepak.title, &[_]u8{ 0, ' ' });
    std.debug.print("Loaded: {s} ({d} bytes) \n", .{ trimmed, gba.gamepak.rom.len });

    const entry = gba.bus.read32(0x08000000);
    std.debug.print("Rom entry point: 0x{X:0>8}\n", .{entry});

    var renderer = platform.Renderer.init();
    defer renderer.deinit();

    while (platform.Renderer.processEvents()) {
        renderer.present();
    }
}
