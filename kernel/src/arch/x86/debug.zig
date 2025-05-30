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
    asm volatile ("xchg %bx, %bx" ::: "bx");
}

const writer = Writer(void, error{}, callback){ .context = {} };

fn callback(_: void, string: []const u8) error{}!usize {
    print(string);
    return string.len;
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    writer.print(format, args) catch unreachable;
}

pub fn printfBuf(comptime format: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    const msg = fmt.bufPrint(&buf, format, args) catch unreachable;
    print(msg);
}

pub fn myLogFn(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;
    const prefix = "[" ++ comptime level.asText() ++ "]: ";
    // if (format.len > 1000) {
    printf(prefix ++ format, args);
    // } else {
    //     printfBuf(prefix ++ format, args);
    // }
}
