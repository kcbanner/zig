//! Optimized for performance in debug builds.

const std = @import("../std.zig");
const MemoryAccessor = std.debug.MemoryAccessor;

const FixedBufferReader = @This();

reader: std.io.Reader,
endian: std.builtin.Endian,

pub const Error = error{ Overflow, InvalidBuffer } || std.io.Reader.Error;

pub fn init(buf: []const u8, endian: std.builtin.Endian) FixedBufferReader {
    return .{
        .reader = .fixed(buf),
        .endian = endian,
    };
}

pub fn initOffset(buf: []const u8, endian: std.builtin.Endian, offset: usize) Error!FixedBufferReader {
    var fbr: FixedBufferReader = .{
        .reader = .fixed(buf),
        .endian = endian,
    };
    try fbr.seekTo(offset);
    return fbr;
}

pub fn seekTo(fbr: *FixedBufferReader, pos: u64) Error!void {
    if (pos > fbr.reader.end) return error.EndOfStream;
    fbr.reader.seek = @intCast(pos);
}

pub fn seekForward(fbr: *FixedBufferReader, amount: u64) Error!void {
    if (fbr.reader.bufferedLen() < amount) return error.EndOfStream;
    fbr.reader.seek += @intCast(amount);
}

pub fn posAddress(fbr: *const FixedBufferReader) u64 {
    return @intFromPtr(&fbr.reader.buffer[fbr.reader.seek]);
}

pub fn takeInt(fbr: *FixedBufferReader, comptime T: type) Error!T {
    return fbr.reader.takeInt(T, fbr.endian);
}

pub fn takeIntChecked(
    fbr: *FixedBufferReader,
    comptime T: type,
    ma: *MemoryAccessor,
) Error!T {
    if (ma.load(T, fbr.posAddress()) == null) return error.InvalidBuffer;
    return fbr.takeInt(T);
}

pub fn takeUleb128(fbr: *FixedBufferReader, comptime T: type) Error!T {
    return std.leb.readUleb128(T, &fbr.reader);
}

pub fn takeIleb128(fbr: *FixedBufferReader, comptime T: type) Error!T {
    return std.leb.readIleb128(T, &fbr.reader);
}

pub fn takeAddress(fbr: *FixedBufferReader, format: std.dwarf.Format) Error!u64 {
    return switch (format) {
        .@"32" => try fbr.takeInt(u32),
        .@"64" => try fbr.takeInt(u64),
    };
}

pub fn takeAddressChecked(
    fbr: *FixedBufferReader,
    format: std.dwarf.Format,
    ma: *MemoryAccessor,
) Error!u64 {
    return switch (format) {
        .@"32" => try fbr.takeIntChecked(u32, ma),
        .@"64" => try fbr.takeIntChecked(u64, ma),
    };
}
