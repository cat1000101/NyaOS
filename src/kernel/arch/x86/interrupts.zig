const std = @import("std");
const idt = @import("idt.zig");
const isr = @import("isr.zig");
const virtio = @import("virtio.zig");

export fn Handler(cpu_state: idt.CpuState) void {
    _ = cpu_state; // autofix

}

export fn commonStub() callconv(.Naked) void {
    asm volatile (
        \\ push corrent state to the stack
        \\  pusha               // pushes in order: eax, ecx, edx, ebx, esp, ebp, esi, edi
        \\
        \\  xor eax, eax
        \\  mov %ds, %ax
        \\  push %ax
        \\  mov %es, %ax
        \\  push %ax
        \\  mov %fs, %ax
        \\  push %ax
        \\  mov %gs, %ax
        \\  push %ax
    );

    asm volatile (
        \\ // this place now is black boxed wawwie
        \\
        \\  mov $0x10, %ax       // use kernel data segment
        \\  mov %ax, %ds
        \\  mov %ax, %es
        \\  mov %ax, %fs
        \\  mov %ax, %gs
        \\
        \\  push %esp            // pass pointer to the cpu state
        \\  call Handler
        \\  add $4, %esp         // remove the pointer to the cpu state
        \\
        \\ // end of black box
    );

    asm volatile (
        \\ // return the state from before
        \\  xor eax, eax
        \\  pop %ax
        \\  mov %ax, %gs
        \\  pop %ax
        \\  mov %ax, %fs
        \\  pop %ax
        \\  mov %ax, %es
        \\  pop %ax
        \\  mov %ax, %ds
        \\
        \\  popa                // pop what we pushed with pusha
        \\  add $8, %esp        // remove the things that we push from the interrupt stub
        \\  iret                // will pop: cs, eip, eflags, ss, esp
    );
}

// stollen/"inspired" from https://github.com/ZystemOS/pluto it is a good zig os
// that is a good refrence for good practive maybe idk
pub fn generateStub(comptime interrupt_num: u32) idt.InterruptStub {
    return struct {
        fn func() callconv(.Naked) void {
            asm volatile (
                \\ cli
            );

            // These interrupts don't push an error code onto the stack, so will push a zero.
            if (interrupt_num != 8 and !(interrupt_num >= 10 and interrupt_num <= 14) and interrupt_num != 17) {
                asm volatile (
                    \\ pushl $0
                );
            }

            asm volatile (
                \\ pushl %[nr]
                \\ jmp commonStub
                :
                : [nr] "n" (interrupt_num),
            );
        }
    }.func;
}
