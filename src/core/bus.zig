const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const log = std.log.scoped(.bus);
const GamePak = @import("gamepak.zig").GamePak;

const config = struct {
    const trace_memory = false; // log elke memory read/write
};

pub const Bus = struct {
    bios: [16 * 1024]u8 = undefined,
    ewram: [256 * 1024]u8 = undefined,
    iwram: [32 * 1024]u8 = undefined,
    palette: [1024]u8 = undefined,
    vram: [96 * 1024]u8 = undefined,
    oam: [1024]u8 = undefined,
    io: [1024]u8 = undefined,
    gamepak: *GamePak,

    pub fn init(gamepak: *GamePak) Bus {
        var bus = Bus{
            .gamepak = gamepak,
        };

        @memset(&bus.bios, 0);
        @memset(&bus.ewram, 0);
        @memset(&bus.iwram, 0);
        @memset(&bus.palette, 0);
        @memset(&bus.vram, 0);
        @memset(&bus.oam, 0);
        @memset(&bus.io, 0);
        return bus;
    }

    pub fn read8(self: *const Bus, address: u32) u8 {
        // Shift 24 bits (6 hex characters), then extract the lower 4 bits (1 hex character)
        const region = (address >> 24) & 0xF;

        const value = switch (region) {
            0x00 => self.bios[address & 0x3FFF],
            0x02 => self.ewram[address & 0x3FFFF],
            0x03 => self.iwram[address & 0x7FFF],
            0x04 => self.io[address & 0x3FF],
            0x05 => self.palette[address & 0x3FF],
            0x06 => self.readVram(address),
            0x07 => self.oam[address & 0x3FF],
            0x08, 0x09 => self.gamepakRead(address), // Rom mirror 1
            0x0A, 0x0B => self.gamepakRead(address), // Rom mirror 2
            0x0C, 0x0D => self.gamepakRead(address), // Rom Mirror 3
            else => 0,
        };

        if (comptime config.trace_memory) {
            log.debug("read8({x:0>8}) = {x:0>2}", .{ address, value });
        }

        return value;
    }

    pub fn write8(self: *Bus, address: u32, value: u8) void {
        if (comptime config.trace_memory) {
            log.debug("write8({x:0>8}, {x:0>2})", .{ address, value });
        }

        const region = (address >> 24) & 0xF;
        switch (region) {
            0x00 => {},
            0x02 => self.ewram[address & 0x3FFFF] = value,
            0x03 => self.iwram[address & 0x7FFF] = value,
            0x04 => self.io[address & 0x3FF] = value,
            0x05 => self.palette[address & 0x3FF] = value,
            0x06 => self.writeVram(address, value),
            0x07 => self.oam[address & 0x3FF] = value,
            else => {},
        }
    }

    fn readVram(self: *const Bus, address: u32) u8 {
        // VRAM = 96KB. Offset mudolo is 128kb but we have 64-96 KB range
        // // mirros from 32-64 KB
        var offset = address & 0x1FFFF; // 128 KB mask
        if (offset >= 0x18000) {
            // Mirror: 96-128KB
            offset -= 0x8000;
        }

        return self.vram[offset];
    }

    fn writeVram(self: *Bus, address: u32, value: u8) void {
        var offset = address & 0x1FFFF;
        if (offset >= 0x18000) {
            offset -= 0x8000;
        }
        self.vram[offset] = value;
    }

    pub fn read16(self: *const Bus, address: u32) u16 {
        const aligned = address & ~@as(u32, 1);
        const lo: u16 = self.read8(aligned);
        const hi: u16 = self.read8(aligned + 1);
        return (hi << 8) | lo;
    }

    pub fn read32(self: *const Bus, address: u32) u32 {
        const aligned = address & ~@as(u32, 3);
        const b0: u32 = self.read8(aligned);
        const b1: u32 = self.read8(aligned + 1);
        const b2: u32 = self.read8(aligned + 2);
        const b3: u32 = self.read8(aligned + 3);
        return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0;
    }

    pub fn write16(self: *Bus, address: u32, value: u16) void {
        const aligned = address & ~@as(u32, 1);
        self.write8(aligned, @truncate(value));
        self.write8(aligned + 1, @truncate(value >> 8));
    }

    pub fn write32(self: *Bus, address: u32, value: u32) void {
        const aligned = address & ~@as(u32, 3);
        self.write8(aligned, @truncate(value));
        self.write8(aligned + 1, @truncate(value >> 8));
        self.write8(aligned + 2, @truncate(value >> 16));
        self.write8(aligned + 3, @truncate(value >> 24));
    }

    fn gamepakRead(self: *const Bus, address: u32) u8 {
        const offset = address & 0x1FFFFFF;
        if (offset < self.gamepak.rom.len) {
            return self.gamepak.rom[offset];
        }
        return 0;
    }
};

test "IWRAM read/write roundtrip u8" {
    var rom_data = [_]u8{ 0x78, 0x56, 0x34, 0x12 };
    var pak = dummyGamePak(&rom_data);
    var bus = Bus.init(&pak);
    bus.write8(0x03000000, 0x42);
    try expectEqual(@as(u8, 0x42), bus.read8(0x03000000));
}

test "IWRAM read/write roundtrip u32" {
    var rom_data = [_]u8{ 0x78, 0x56, 0x34, 0x12 };
    var pak = dummyGamePak(&rom_data);
    var bus = Bus.init(&pak);
    bus.write32(0x03000000, 0x12345678);
    try expectEqual(@as(u32, 0x12345678), bus.read32(0x03000000));
}

test "BIOS regio is read-only" {
    var rom_data = [_]u8{ 0x78, 0x56, 0x34, 0x12 };
    var pak = dummyGamePak(&rom_data);
    var bus = Bus.init(&pak);
    bus.write8(0x0000000, 0xFF);
    try expectEqual(@as(u8, 0), bus.read8(0x00000000));
}

test "little-endian read16 from two seperate bytes" {
    var rom_data = [_]u8{ 0x78, 0x56, 0x34, 0x12 };
    var pak = dummyGamePak(&rom_data);
    var bus = Bus.init(&pak);
    bus.write8(0x03000000, 0x78);
    bus.write8(0x03000001, 0x56);
    try expectEqual(@as(u16, 0x5678), bus.read16(0x03000000));
}

test "little-endian write16 reads as two bytes" {
    var rom_data = [_]u8{ 0x78, 0x56, 0x34, 0x12 };
    var pak = dummyGamePak(&rom_data);
    var bus = Bus.init(&pak);

    bus.write16(0x03000000, 0xABCD);
    try expectEqual(@as(u8, 0xCD), bus.read8(0x03000000)); // low byte
    try expectEqual(@as(u8, 0xAB), bus.read8(0x03000001)); // High byte
}

test "GamePak ROM read via bus" {
    // Maak een kleine nep-ROM
    var rom_data = [_]u8{ 0x78, 0x56, 0x34, 0x12 };
    var pak = dummyGamePak(&rom_data);
    var bus = Bus.init(&pak);

    // Lees individuele bytes
    try std.testing.expectEqual(@as(u8, 0x78), bus.read8(0x08000000));
    try std.testing.expectEqual(@as(u8, 0x56), bus.read8(0x08000001));

    // 32-bit little-endian read
    try std.testing.expectEqual(@as(u32, 0x12345678), bus.read32(0x08000000));

    // ROM mirror: 0x0A000000 leest dezelfde data
    try std.testing.expectEqual(@as(u8, 0x78), bus.read8(0x0A000000));

    // Read voorbij ROM-grootte geeft 0
    try std.testing.expectEqual(@as(u8, 0), bus.read8(0x08000010));
}

fn dummyGamePak(romData: []u8) GamePak {
    return GamePak{
        .rom = romData,
        .title = [_]u8{0} ** 12,
        .game_code = [_]u8{0} ** 4,
        .allocator = std.testing.allocator,
        .rom_path = "test.gba",
    };
}
