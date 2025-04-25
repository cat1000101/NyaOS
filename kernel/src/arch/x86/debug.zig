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

const levels = struct {
    infoPrintLevel: bool,
    debugPrintLevel: bool,
    errorPrintLevel: bool,
};

pub var printLevels: levels = .{
    .infoPrintLevel = true,
    .errorPrintLevel = true,
    .debugPrintLevel = false,
};

pub fn infoPrint(comptime format: []const u8, args: anytype) void {
    if (!printLevels.infoPrintLevel) return;
    printf("[INFO]: " ++ format, args);
}

pub fn debugPrint(comptime format: []const u8, args: anytype) void {
    if (!printLevels.debugPrintLevel) return;
    printf("[DEBUG]: " ++ format, args);
}

pub fn errorPrint(comptime format: []const u8, args: anytype) void {
    if (!printLevels.errorPrintLevel) return;
    printf("[ERROR]: " ++ format, args);
}
