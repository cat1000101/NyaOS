const multiboot = @import("../multiboot.zig");
const paging = @import("../arch/x86/paging.zig");
const vga = @import("../arch/x86/vga.zig");

const std = @import("std");
const log = std.log;

const logo = "                           /^--^\\     /^--^\\     /^--^\\                                                    \\____/     \\____/     \\____/                                                  /      \\   /      \\   /      \\                                                  |        | |        | |        |                                                \\__  __/   \\__  __/   \\__  __/                            |^|^|^|^|^|^|^|^|^|^|^|^\\ \\^|^|^|^/ /^|^|^|^|^\\ \\^|^|^|^|^|^|^|^|^|^|^|^|       | | | | | | | | | | | | |\\ \\| | |/ /| | | | | | \\ \\ | | | | | | | | | | |       ########################/ /######\\ \\###########/ /#######################       | | | | | | | | | | | | \\/| | | | \\/| | | | | |\\/ | | | | | | | | | | | |       |_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|    ";
pub var framebuffer: FrameBuffer = undefined;

const video = true;

pub fn initialize() void {
    if (!video) {
        vga.clear();
        printf("{s}", .{logo});
    } else {
        framebuffer = FrameBuffer.initFrameBuffer() orelse {
            log.err("No framebuffer found\n", .{});
            return;
        };
    }
}

pub fn putChar(c: u8) void {
    vga.putChar(c);
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    vga.printf(format, args);
}

pub const FrameBuffer = struct {
    frameBuffer: []volatile Pixel,
    width: u32,
    height: u32,
    pitch: u32,
    bpp: u32,

    /// from my understanding when asking grub for framebuffer with depth 32 the pixels most of the time
    /// are in the order of blue green red and padding all 8 bits
    pub const Pixel = packed struct {
        blue0: u8,
        green1: u8,
        red2: u8,
        padding: u8 = 0,
    };

    pub const FrameBufferError = error{
        IncompatibleSize,
    };

    /// get the info from multiboot about the framebuffer and return the slice to the framebuffer
    pub fn initFrameBuffer() ?FrameBuffer {
        const frameBufferInfo = multiboot.getVideoFrameBuffer() orelse {
            log.err("No framebuffer found\n", .{});
            return null;
        };
        log.info("screen frame buffer: {}\n", .{frameBufferInfo});

        const sizeInPixels = frameBufferInfo.framebuffer_width * frameBufferInfo.framebuffer_height;
        log.err("size in pixels: 0x{X}\n", .{sizeInPixels});
        var retFrameBuffer = FrameBuffer{
            .frameBuffer = @as([*]volatile Pixel, @ptrFromInt(frameBufferInfo.framebuffer_addr))[0..sizeInPixels],
            .width = frameBufferInfo.framebuffer_width,
            .height = frameBufferInfo.framebuffer_height,
            .pitch = frameBufferInfo.framebuffer_pitch,
            .bpp = frameBufferInfo.framebuffer_bpp,
        };

        paging.idPagesRecursivly(
            frameBufferInfo.framebuffer_addr,
            frameBufferInfo.framebuffer_addr,
            std.mem.alignForward(u32, sizeInPixels * @sizeOf(Pixel), 0x1000),
            true,
        ) catch |err| {
            log.err("Failed to map framebuffer: {}\n", .{err});
            return null;
        };

        retFrameBuffer.clearColor(.{
            .blue0 = 255,
            .green1 = 116,
            .red2 = 51,
        });

        // log.info("initFrameBuffer: retFrameBuffer: {}", .{retFrameBuffer});

        return retFrameBuffer;
    }

    pub fn putPixel(this: *FrameBuffer, x: usize, y: usize, color: Pixel) void {
        const index = y * this.width + x;
        this.frameBuffer[index] = color;
    }

    pub fn clearColor(this: *FrameBuffer, color: Pixel) void {
        @memset(this.frameBuffer, color);
    }

    pub fn clear(this: *FrameBuffer) void {
        const color = Pixel{ .blue0 = 0, .green1 = 0, .red2 = 0, .padding = 0 };
        this.clearColor(color);
    }

    pub fn flushWithFrame(this: *FrameBuffer, frame: []Pixel) !void {
        if (frame.len != this.frameBuffer.len) {
            log.err("frame length: 0x{X} frameBuffer size: 0x{X}\n", .{
                frame.len,
                this.frameBuffer.len,
            });
            return FrameBufferError.IncompatibleSize;
        }
        @memcpy(this.frameBuffer, frame);
    }
};
