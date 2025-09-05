const fmt = @import("std").fmt;
const Writer = @import("std").io.Writer;

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
const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_SIZE = VGA_WIDTH * VGA_HEIGHT;

var textRow: usize = 0;
var textColumn: usize = 0;
var charColor = vgaEntryColor(ConsoleColors.LightGray, ConsoleColors.Black);
var buffer = @as([*]volatile u16, @ptrFromInt(0xC00B8000));

const VGA_VIDEO_WIDTH = 320;
const VGA_VIDEO_HEIGHT = 200;
const VGA_VIDEO_SIZE = VGA_VIDEO_WIDTH * VGA_VIDEO_HEIGHT;
var videoBuffer = @as([*]volatile u8, @ptrFromInt(0xC00A0000));

fn vgaEntryColor(fg: ConsoleColors, bg: ConsoleColors) u8 {
    return @intFromEnum(fg) | (@intFromEnum(bg) << 4);
}

fn vgaEntry(uc: u8, new_color: u8) u16 {
    const c: u16 = new_color;

    return uc | (c << 8);
}

pub fn setColor(new_color: u8) void {
    charColor = new_color;
}

pub fn clear() void {
    @memset(buffer[0..VGA_SIZE], vgaEntry(' ', charColor));
}

pub fn putCharAt(c: u8, new_color: u8, x: usize, y: usize) void {
    const index = y * VGA_WIDTH + x;
    buffer[index] = vgaEntry(c, new_color);
}

pub fn putChar(c: u8) void {
    if (c == '\n') {
        textColumn = 0;
        textRow += 1;
        if (textRow == VGA_HEIGHT)
            nextLine();
        return;
    } else {
        putCharAt(c, charColor, textColumn, textRow);
    }

    textColumn += 1;
    if (textColumn == VGA_WIDTH) {
        textColumn = 0;
        textRow += 1;
        if (textRow == VGA_HEIGHT)
            nextLine();
    }
}

fn nextLine() void {
    for (VGA_WIDTH..(VGA_WIDTH * VGA_HEIGHT - 1)) |i|
        buffer[i - VGA_WIDTH] = buffer[i];
}

pub var vgaTextWriter = Writer{
    .buffer = &[0]u8{},
    .vtable = &.{
        .drain = &callback,
    },
};

fn callback(_: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
    var bytesWritten: usize = 0;
    for (data, 0..) |dataSlice, index| {
        if (index == data.len - 1) {
            for (0..splat) |_| {
                for (dataSlice) |c|
                    putChar(c);
            }
            bytesWritten = bytesWritten + (dataSlice.len * splat);
            return bytesWritten;
        }
        bytesWritten = bytesWritten + dataSlice.len;
        for (dataSlice) |c|
            putChar(c);
    }
    return bytesWritten;
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    vgaTextWriter.print(format, args) catch unreachable;
}
