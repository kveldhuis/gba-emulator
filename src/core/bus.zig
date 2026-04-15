const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "IWRAM read/write roundtrip u8" {
    var bus = Bus.init();
    bus.write8(0x03000000, 0x42);
    try expectEqual(@as(u8, 0x42), bus.read(0x03000000));
}

test "IWRAM read/write roundtrip u32" {
    var bus = Bus.init();
    bus.write32(0x03000000, 0x12345678);
    try expectEqual(@as(u32, 0x12345678), bus.read(0x03000000));
}

test "BIOS regio is read-only" {
    var bus = Bus.init();
    bus.write8(0x0000000, 0xFF);
    try expectEqual(@as(u8, 0), bus.read(0x00000000));
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
