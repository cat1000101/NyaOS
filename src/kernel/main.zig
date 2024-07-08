const kmain = @import("kmain.zig");

const ALIGN = 1 << 0;
const MEMINFO = 1 << 1;
const MAGIC = 0x1BADB002;
const FLAGS = ALIGN | MEMINFO;

const MultibootHeader = extern struct {
    magic: i32 = MAGIC,
    flags: i32 align(1),
    checksum: i32 align(1),
};

export var multiboot align(4) linksection(".multiboot") = MultibootHeader{
    .flags = FLAGS,
    .checksum = -(MAGIC + FLAGS),
};

export var stack: [16 * 1024 + 1]u8 align(16) linksection(".bss") = undefined;
export const stack_top = &stack[stack.len - 1];

comptime {
    _ = kmain;
    asm (
        \\.section .text
        \\.global _start
        \\.type _start, @function
        \\_start:
        \\mov stack_top, %esp
        \\call kmain
        \\cli
        \\1: hlt
        \\jmp 1b
        \\
        \\.size _start, . - _start
    );
}
