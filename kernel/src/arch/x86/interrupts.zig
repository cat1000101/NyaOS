const std = @import("std");
const idt = @import("idt.zig");
const virtio = @import("virtio.zig");

export fn Handler(cpu_state: *IsrCpuState) void {
    if (cpu_state.interrupt_number == 14) {
        var faulting_address: u32 = 0;
        asm volatile ("mov %cr2, %[faulting_address]"
            : [faulting_address] "=r" (faulting_address),
        );

        virtio.printf("page fault error: 0x{x}, address: 0x{x}\n", .{ cpu_state.error_code, faulting_address });
    } else {
        virtio.printf("interrupt has accured yippe interrupt/exeption:{}, error:{}\n", .{ cpu_state.interrupt_number, cpu_state.error_code });
    }
}

// cpu state when calling isr intrupt
pub const IsrCpuState = extern struct {
    // Segment registers pushed manually
    gs: u16,
    fs: u16,
    es: u16,
    ds: u16,

    // General-purpose registers pushed by pusha
    edi: u32,
    esi: u32,
    ebp: u32,
    esp: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,

    interrupt_number: u32, // Interrupt number pushed by me :3

    // Items pushed by the CPU during an interrupt
    error_code: u32, // Error code pushed by the interrupt or us
    eip: u32,
    cs: u32,
    eflags: u32,

    // Items pushed by the CPU if a privilege level change occurs ¯\_(ツ)_/¯
    // idk so there is the option for latter ignore for now
    user_esp: u32, // ESP if there is a privilege level change
    ss: u32, // SS if there is a privilege level change
};

// cpu state when using generateStub
pub const CpuState = extern struct {
    // Segment registers pushed manually
    gs: u16,
    fs: u16,
    es: u16,
    ds: u16,

    // General-purpose registers pushed by pusha
    edi: u32,
    esi: u32,
    ebp: u32,
    esp: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,
};

export fn isrCommonStub() callconv(.Naked) void {
    // push corrent state to the stack
    asm volatile (
        \\  pusha               // pushes in order: eax, ecx, edx, ebx, esp, ebp, esi, edi
        \\
        \\  xor %eax, %eax
        \\  mov %ds, %ax
        \\  push %ax
        \\  mov %es, %ax
        \\  push %ax
        \\  mov %fs, %ax
        \\  push %ax
        \\  mov %gs, %ax
        \\  push %ax
    );

    // this place now is black boxed wawwie
    asm volatile (
        \\  mov $0x10, %ax       // use kernel data segment
        \\  mov %ax, %ds
        \\  mov %ax, %es
        \\  mov %ax, %fs
        \\  mov %ax, %gs
        \\
        \\  push %esp            // pass pointer to the cpu state
        \\  call %[Handler:P]
        \\  add $4, %esp         // remove the pointer to the cpu state
        :
        : [Handler] "X" (&Handler),
    );
    // end of black box

    // return the state from before
    asm volatile (
        \\  xor %eax, %eax
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
        \\  add $8, %esp        // remove the error code that was pushed by us or the cpu and the interrupt number
        \\  iret                // will pop: cs, eip, eflags and ss, esp if there was a privlige level change
    );
}

pub fn generateStub(function: *const fn () callconv(.C) void) fn () callconv(.Naked) void {
    return struct {
        fn func() callconv(.Naked) void {
            asm volatile (
                \\  pusha               // pushes in order: eax, ecx, edx, ebx, esp, ebp, esi, edi
                \\
                \\  xor %eax, %eax
                \\  mov %ds, %ax
                \\  push %ax
                \\  mov %es, %ax
                \\  push %ax
                \\  mov %fs, %ax
                \\  push %ax
                \\  mov %gs, %ax
                \\  push %ax
            );

            // this place now is black boxed wawwie
            asm volatile (
                \\  mov $0x10, %ax       // use kernel data segment
                \\  mov %ax, %ds
                \\  mov %ax, %es
                \\  mov %ax, %fs
                \\  mov %ax, %gs
            );
            asm volatile (
                \\  push %esp            // pass pointer to the cpu state
                \\  call *%[function:P]
                \\  add $4, %esp         // remove the pointer to the cpu state
                :
                : [function] "X" (&function),
            );
            // end of black box

            asm volatile (
                \\  xor %eax, %eax
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
                \\  iret                // will pop: cs, eip, eflags and ss, esp if there was a privlige level change
            );
        }
    }.func;
}

// stollen/"inspired" from https://github.com/ZystemOS/pluto it is a good zig os
// that is a good refrence for good practive maybe idk
fn generateIsrStub(comptime interrupt_num: u32) fn () callconv(.Naked) void {
    return struct {
        fn func() callconv(.Naked) void {
            asm volatile (
                \\ cli
            );

            // These interrupts don't push an error code onto the stack, so will push a zero. meanng 0-31 other then those
            if (interrupt_num != 8 and !(interrupt_num >= 10 and interrupt_num <= 14) and interrupt_num != 17) {
                asm volatile (
                    \\ pushl $0
                );
            }

            asm volatile (
                \\ pushl %[nr]
                \\ jmp %[isrCommonStub:P]
                :
                : [nr] "n" (interrupt_num),
                  [isrCommonStub] "X" (&isrCommonStub),
            );
        }
    }.func;
}

pub fn installIsr() void {
    comptime var i = 0;
    inline while (i < 32) : (i += 1) {
        const interrupt = generateIsrStub(i);
        idt.openIdtGate(i, &interrupt) catch |err| switch (err) {
            idt.InterruptError.interruptOpen => {
                virtio.printf("wtf did u do??????????(isr interrupt already open)\n", .{});
            },
        };
    }

    virtio.printf("installed isr\n", .{});
}
