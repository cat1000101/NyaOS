// brain storming:
// get the end of the kernel where there should be free memory that is not under 1MB
// also get the size of the free memory fro mthe bootloader/multiboot
// at the end i align and put the bitmap at the end of the kernel
// fill the bitmap for existing memory
const multiboot = @import("../multiboot.zig");
const virtio = @import("../arch/x86/virtio.zig");

extern const kernel_start: u32;
extern const kernel_end: u32;

pub fn initPmm() void {
    const multibootInfo = multiboot.multibootInfo;
    _ = multibootInfo; // autofix
    virtio.printf("kernel start: 0x{x} kernel end: 0x{x}\n", .{ @intFromPtr(&kernel_start), @intFromPtr(&kernel_end) });
}
