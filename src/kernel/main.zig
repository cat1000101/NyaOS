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
export var stack: [16 * 1024 + 1]u8 align(16) linksection(".bss") = undefined;
export const stack_top = &stack[stack.len - 1];

// putting the stack to the stack pointer
// jumping to the kmain lower half of the kernel?
comptime {
    _ = kmain;
    asm (
        \\.section .text
        \\.global _start
        \\.type _start, @function
        \\_start:
        \\  mov stack_top, %esp
        \\  push %ebx
        \\  call kmain
        \\  cli
        \\1: hlt
        \\  jmp 1b
        \\
        \\.size _start, . - _start
    );
}
