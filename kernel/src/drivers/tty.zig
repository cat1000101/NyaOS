const fmt = @import("std").fmt;
const Writer = @import("std").io.Writer;

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_SIZE = VGA_WIDTH * VGA_HEIGHT;

pub const ConsoleColors = enum(u8) {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGray = 7,
    DarkGray = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    LightMagenta = 13,
    LightBrown = 14,
    White = 15,
};

var row: usize = 0;
var column: usize = 0;
var color = vgaEntryColor(ConsoleColors.LightGray, ConsoleColors.Black);
var buffer = @as([*]volatile u16, @ptrFromInt(0xB8000)); // 0xC00B8000

const logo = "                           /^--^\\     /^--^\\     /^--^\\                                                    \\____/     \\____/     \\____/                                                  /      \\   /      \\   /      \\                                                  |        | |        | |        |                                                \\__  __/   \\__  __/   \\__  __/                            |^|^|^|^|^|^|^|^|^|^|^|^\\ \\^|^|^|^/ /^|^|^|^|^\\ \\^|^|^|^|^|^|^|^|^|^|^|^|       | | | | | | | | | | | | |\\ \\| | |/ /| | | | | | \\ \\ | | | | | | | | | | |       ########################/ /######\\ \\###########/ /#######################       | | | | | | | | | | | | \\/| | | | \\/| | | | | |\\/ | | | | | | | | | | | |       |_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|    ";

fn vgaEntryColor(fg: ConsoleColors, bg: ConsoleColors) u8 {
    return @intFromEnum(fg) | (@intFromEnum(bg) << 4);
}

fn vgaEntry(uc: u8, new_color: u8) u16 {
    const c: u16 = new_color;

    return uc | (c << 8);
}

pub fn initialize() void {
    clear();
    printf("{s}", .{logo});
}

pub fn setColor(new_color: u8) void {
    color = new_color;
}

pub fn clear() void {
    @memset(buffer[0..VGA_SIZE], vgaEntry(' ', color));
}

pub fn putCharAt(c: u8, new_color: u8, x: usize, y: usize) void {
    const index = y * VGA_WIDTH + x;
    buffer[index] = vgaEntry(c, new_color);
}

pub fn putChar(c: u8) void {
    if (c == '\n') {
        column = 0;
        row += 1;
        if (row == VGA_HEIGHT)
            nextLine();
        return;
    } else {
        putCharAt(c, color, column, row);
    }

    column += 1;
    if (column == VGA_WIDTH) {
        column = 0;
        row += 1;
        if (row == VGA_HEIGHT)
            nextLine();
    }
}

fn nextLine() void {
    for (VGA_WIDTH..(VGA_WIDTH * VGA_HEIGHT - 1)) |i|
        buffer[i - VGA_WIDTH] = buffer[i];
}

pub fn puts(data: []const u8) void {
    for (data) |c|
        putChar(c);
}

pub const writer = Writer(void, error{}, callback){ .context = {} };

fn callback(_: void, string: []const u8) error{}!usize {
    puts(string);
    return string.len;
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    fmt.format(writer, format, args) catch unreachable;
}
