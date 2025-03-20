const kmain = @import("kmain.zig");
const paging = @import("arch/x86/paging.zig");

// multiboot headers values
const ALIGN = 1 << 0;
const MEMINFO = 1 << 1;
const MAGIC = 0x1BADB002;
const FLAGS = ALIGN | MEMINFO;

// multiboot struct
const MultibootHeader = extern struct {
    magic: i32 = MAGIC,
    flags: i32 align(1),
    checksum: i32 align(1),
};

// exporting the multiboot headers so that grub can find it
export var multiboot align(4) linksection(".multiboot") = MultibootHeader{
    .flags = FLAGS,
    .checksum = -(MAGIC + FLAGS),
};

const kernelNumberOf4MIBPages = 1;
// setting up the paging stolen from https://github.com/ZystemOS/pluto again
export var tempBootPageDirectory: [1024]u32 align(paging.NUMBER_OF_BYTES_IN_4KIB) linksection(".boot") = init: {
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
    while (i < paging.FIRST_KERNEL_PAGE_NUMBER - 1) : ({
        i += 1;
        idx += 1;
    }) {
        dir[idx] = 0;
    }

    // Map the kernel's higher half pages increasing by 4 MiB every time
    i = 0;
    while (i < kernelNumberOf4MIBPages) : ({ //paging.kernel_size_in_4MIB_pages) : ({
        i += 1;
        idx += 1;
    }) {
        dir[idx] = basicFlags | (i << 22);
    }
    // Fill succeeding pages with zeroes. May be unnecessary but incurs no runtime cost
    i = 0;
    while (i < 1024 - paging.FIRST_KERNEL_PAGE_NUMBER - kernelNumberOf4MIBPages) : ({ // paging.NUMBER_OF_4MIB_KERNEL_PAGES) : ({
        i += 1;
        idx += 1;
    }) {
        dir[idx] = 0;
    }
    break :init dir;
};

// entery point and setting up paging and jumping to higher half entery point of the kernel
export fn _start() align(16) linksection(".boot") callconv(.Naked) noreturn {
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
        \\  jmp high_half_entery
    );
    while (true) {
        asm volatile ("hlt");
    }
}

// setting up stack manually
export var stack: [16 * 1024]u8 align(16) linksection(".bss") = undefined;
export const stack_top = &stack[stack.len - 1];

// putting the stack to the stack pointer
// jumping to the kmain lower half of the kernel?
export fn high_half_entery() align(16) callconv(.Naked) noreturn {
    _ = kmain;
    asm volatile (
        \\  .extern stack_top
        \\  mov $stack_top, %esp
        \\  push %eax
        \\  push %ebx
        \\  call kmain
    );
    while (true) {
        asm volatile ("hlt");
    }
}
