const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const log = std.log.scoped(.bus);

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

    pub fn init() Bus {
        var bus = Bus{};

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
        const aligned = address & ~@as(u32, 1);
        self.write8(aligned, @truncate(value));
        self.write8(aligned + 1, @truncate(value >> 8));
        self.write8(aligned + 2, @truncate(value >> 16));
        self.write8(aligned + 3, @truncate(value >> 24));
    }
};

test "IWRAM read/write roundtrip u8" {
    var bus = Bus.init();
    bus.write8(0x03000000, 0x42);
    try expectEqual(@as(u8, 0x42), bus.read8(0x03000000));
}

test "IWRAM read/write roundtrip u32" {
    var bus = Bus.init();
    bus.write32(0x03000000, 0x12345678);
    try expectEqual(@as(u32, 0x12345678), bus.read32(0x03000000));
}

test "BIOS regio is read-only" {
    var bus = Bus.init();
    bus.write8(0x0000000, 0xFF);
    try expectEqual(@as(u8, 0), bus.read8(0x00000000));
}

test "little-endian read16 from two seperate bytes" {
    var bus = Bus.init();
    bus.write8(0x03000000, 0x78);
    bus.write8(0x03000001, 0x56);
    try expectEqual(@as(u16, 0x5678), bus.read16(0x03000000));
}

test "little-endian write16 reads as two bytes" {
    var bus = Bus.init();
    bus.write16(0x03000000, 0xABCD);
    try expectEqual(@as(u8, 0xCD), bus.read8(0x03000000)); // low byte
    try expectEqual(@as(u8, 0xAB), bus.read8(0x03000001)); // High byte
}
