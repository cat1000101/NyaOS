const kmainFile = @import("kmain.zig");
const paging = @import("arch/x86/paging.zig");
const memory = @import("mem/memory.zig");
const multibootType = @import("multiboot.zig");

// multiboot headers values
const MAGIC: u32 = 0x1BADB002;
const FLAGS: u32 = 1 << 0 | 1 << 1 | 1 << 2;

// multiboot struct
const MultibootHeader = extern struct {
    magic: u32 = MAGIC,
    flags: u32 = FLAGS,
    checksum: u32 = 0xFFFFFFFF - (MAGIC + FLAGS - 1),
    header_addr: u32 = 0,
    load_addr: u32 = 0,
    load_end_addr: u32 = 0,
    bss_end_addr: u32 = 0,
    entry_addr: u32 = 0,
    mode_type: u32 = 0,
    width: u32 = 320,
    height: u32 = 200,
    depth: u32 = 32,
};

// exporting the multiboot headers so that grub can find it
export var multiboot: MultibootHeader align(4) linksection(".multiboot") = .{};

const kernelNumberOf4MIBPages = 1;
// setting up the paging stolen from https://github.com/ZystemOS/pluto again
pub export var tempBootPageDirectory: [1024]u32 align(memory.PAGE_SIZE) linksection(".boot") = init: {
    // Increase max number of branches done by comptime evaluator
    @setEvalBranchQuota(1024);
    // Temp value
    var dir: [1024]u32 = undefined;

    const basicFlags = paging.DENTRY_4MB_PAGES | paging.DENTRY_PRESENT | paging.DENTRY_READ_WRITE;

    // Page for 0 -> 4 MiB. Gets unmapped later hopefully
    dir[0] = basicFlags;

    var i = 0;
    var idx = 1;

    // Fill preceding pages with zeroes. May be unnecessary but incurs no runtime cost
    while (i < paging.FIRST_KERNEL_DIR_NUMBER - 1) : ({
        i += 1;
        idx += 1;
    }) {
        dir[idx] = 0;
    }

    // Map the kernel's higher half pages increasing by 4 MiB every time
    i = 0;
    while (i < kernelNumberOf4MIBPages) : ({
        i += 1;
        idx += 1;
    }) {
        dir[idx] = basicFlags | (i << 22);
    }
    // Fill succeeding pages with zeroes. May be unnecessary but incurs no runtime cost
    i = 0;
    while (i < 1024 - paging.FIRST_KERNEL_DIR_NUMBER - kernelNumberOf4MIBPages) : ({
        i += 1;
        idx += 1;
    }) {
        dir[idx] = 0;
    }
    break :init dir;
};

// entery point and setting up paging and jumping to higher half entery point of the kernel
pub export fn _start() align(16) linksection(".boot") callconv(.naked) noreturn {
    asm volatile (
        \\  push %eax
        \\  push %ebx
    );
    tempBootPageDirectory[1023] = @intFromPtr(&tempBootPageDirectory) | paging.DENTRY_PRESENT | paging.DENTRY_READ_WRITE;
    asm volatile (
        \\  pop %ebx
        \\  pop %eax
    );

    // Set the page directory to the boot directory
    asm volatile (
        \\  .extern tempBootPageDirectory
        \\  mov $tempBootPageDirectory, %ecx
        \\  mov %ecx, %cr3
    );

    // Enable 4 MiB pages
    asm volatile (
        \\  mov %cr4, %ecx
        \\  or $0x00000010, %ecx
        \\  mov %ecx, %cr4
    );

    // Enable paging
    asm volatile (
        \\  mov %cr0, %ecx
        \\  or $0x80000000, %ecx
        \\  mov %ecx, %cr0
    );
    asm volatile (
        \\  jmp %[high_half_entery:P]
        :
        : [high_half_entery] "X" (&high_half_entery),
    );
    while (true) {
        asm volatile ("hlt");
    }
}

// setting up stack manually
pub export var stack: [2 * 4096]u8 align(16) linksection(".bss") = undefined;
pub export const stack_top = &stack[stack.len - 1];

// putting the stack to the stack pointer
// jumping to the kmain lower half of the kernel?
export fn high_half_entery() align(16) callconv(.naked) noreturn {
    asm volatile (
        \\  mov %[stack_top], %esp
        \\  mov %esp, %ebp
        \\
        \\  pushl %eax
        \\  pushl %ebx
        \\  pushl $0
        \\  jmp %[kmain:P]
        :
        : [kmain] "X" (&kmainFile.kmain),
          [stack_top] "{edx}" (stack_top),
    );
    while (true) {
        asm volatile ("hlt");
    }
}
