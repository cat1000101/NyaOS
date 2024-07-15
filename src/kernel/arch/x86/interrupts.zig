const std = @import("std");
const idt = @import("idt.zig");
const virtio = @import("virtio.zig");

pub fn commonIsr() callconv(.Naked) void {
    asm volatile (
        \\  pusha               // pushes in order: eax, ecx, edx, ebx, esp, ebp, esi, edi
        \\
        \\  xor %eax, %eax
        \\  mov %ds, %ax
        \\  push %eax            // push ds
        \\
        \\  mov $0x10, %ax       // use kernel data segment
        \\  mov %ax, %ds
        \\  mov %ax, %es
        \\  mov %ax, %fs
        \\  mov %ax, %gs
        \\
        \\  push %esp            // pass pointer to stack to C, so we can access all the pushed information
        \\  call Handler
        \\  add $4, %esp
        \\
        \\  pop %eax             // restore old segment
        \\  mov %ax, %ds
        \\  mov %ax, %es
        \\  mov %ax, %fs
        \\  mov %ax, %gs
        \\
        \\  popa                // pop what we pushed with pusha
        \\  add $8, %esp        // remove error code and interrupt number
        \\  iret                // will pop: cs, eip, eflags, ss, esp
    );
}

pub export fn temp() callconv(.Naked) void {
    asm volatile (
        \\  pusha               // pushes in order: eax, ecx, edx, ebx, esp, ebp, esi, edi
    );

    // asm volatile (
    //     \\ mov $0x4D, %al
    //     \\ outb %al, $0xe9
    // );

    asm volatile (
        \\  popa
        \\  iret
    );
}

export fn printmeow() void {
    virtio.outb("meow?");
}
