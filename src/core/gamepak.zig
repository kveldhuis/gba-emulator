const std = @import("std");

pub const GamePak = struct {
    rom: []u8,
    title: [12]u8,
    game_code: [4]u8,
    allocator: std.mem.Allocator,

    pub fn load(allocator: std.mem.Allocator, path: []const u8) !GamePak {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const rom = try file.readToEndAlloc(allocator, 32 * 1024 * 1024); // Max 32mb

        // Validate max length
        if (rom.len < 0xC0) {
            allocator.free(rom);
            return error.RomTooSmall;
        }

        // Parse header
        var title: [12]u8 = undefined;
        @memcpy(&title, rom[0xA0..0xAC]);

        var gamecode: [4]u8 = undefined;
        @memcpy(&gamecode, rom[0xAC..0xB0]);

        return GamePak{ .rom = rom, .title = title, .game_code = gamecode, .allocator = allocator };
    }

    pub fn deinit(self: *GamePak) void {
        self.allocator.free(self.rom);
    }
};
