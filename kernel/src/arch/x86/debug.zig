const std = @import("std");
const fmt = std.fmt;
const Writer = @import("std").io.Writer;

// debug.printf("debug print src: {s}:{}:{}\n", .{ @src().file, @src().line, @src().column });
pub fn print(s: []const u8) void {
    for (s) |char| {
        putcharAsm(char);
    }
}

pub fn putcharAsm(c: u8) void {
    asm volatile ("outb %[c],$0xe9"
        :
        : [c] "{al}" (c),
    );
}

pub fn bochsBreak() void {
    asm volatile ("xchg %bx, %bx" ::: .{ .bx = true });
}

pub var qemuWriter: Writer = .{
    .buffer = &[0]u8{},
    .vtable = &.{
        .drain = &qemuElizabethWriterDrain,
    },
};

fn qemuElizabethWriterDrain(_: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
    var bytesWritten: usize = 0;
    for (data, 0..) |dataSlice, index| {
        if (index == data.len - 1) {
            for (0..splat) |_| {
                print(dataSlice);
            }
            bytesWritten = bytesWritten + (dataSlice.len * splat);
            return bytesWritten;
        }
        bytesWritten = bytesWritten + dataSlice.len;
        print(dataSlice);
    }
    return bytesWritten;
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    qemuWriter.print(format, args) catch unreachable;
}

pub fn myLogFn(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;
    const prefix = "[" ++ comptime level.asText() ++ "]: ";
    printf(prefix ++ format, args);
}
