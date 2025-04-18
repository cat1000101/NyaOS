const fmt = @import("std").fmt;
const Writer = @import("std").io.Writer;

// debug.printf("debug print src: {s}:{}:{}\n", .{ @src().file, @src().line, @src().column });
fn print(s: []const u8) void {
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
    asm volatile ("xchg %bx, %bx");
}

const writer = Writer(void, error{}, callback){ .context = {} };

fn callback(_: void, string: []const u8) error{}!usize {
    print(string);
    return string.len;
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    fmt.format(writer, format, args) catch unreachable;
}
