const kmain = @import("kmain.zig");

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

// setting up stack manually
export var stack: [16 * 1024]u8 align(16) linksection(".bss") = undefined;
export const stack_top = &stack[stack.len - 1];

// putting the stack to the stack pointer
// jumping to the kmain lower half of the kernel?
comptime {
    _ = kmain;
    asm (
        \\.section .text
        \\.global high_half_entery
        \\.type high_half_entery, @function
        \\high_half_entery:
        \\  mov stack_top, %esp
        \\  push %eax
        \\  push %ebx
        \\  call kmain
        \\
        \\  cli
        \\end_allert: 
        \\  hlt
        \\  jmp end_allert
        \\
        \\.size high_half_entery, . - high_half_entery
    );
}

// entery point and setting up paging and jumping to higher half entery point of the kernel
comptime {
    asm (
        \\.section .boot
        \\.global _start
        \\.type _start, @function
        \\_start:
        \\
        \\
        \\  jmp high_half_entery
        \\  cli
        \\end_allert_paging:
        \\  hlt
        \\  jmp end_allert_paging
        \\
        \\.size _start, . - _start
    );
}
