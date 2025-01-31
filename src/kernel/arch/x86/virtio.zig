const fmt = @import("std").fmt;
const Writer = @import("std").io.Writer;

fn outb(s: []const u8) void {
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

pub const writer = Writer(void, error{}, callback){ .context = {} };

fn callback(_: void, string: []const u8) error{}!usize {
    outb(string);
    return string.len;
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    fmt.format(writer, format, args) catch unreachable;
}
