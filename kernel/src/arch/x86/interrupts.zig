const std = @import("std");
const idt = @import("idt.zig");
const virtio = @import("virtio.zig");

export fn Handler(cpu_state: *IsrCpuState) void {
    switch (cpu_state.interrupt_number) {
        0x00...0x1F => {
            // half stolen thing for the printing: https://github.com/Ashet-Technologies/Ashet-OS/blob/9b595e38815dcc1ed1f7e20abd44ab43c1a63012/src/kernel/port/platform/x86/idt.zig#L67
            virtio.printf("Unhandled exception 0x{x}: {s}\n", .{ cpu_state.interrupt_number, @as([]const u8, switch (cpu_state.interrupt_number) {
                0x00 => "Divide By Zero",
                0x01 => "Debug",
                0x02 => "Non Maskable Interrupt",
                0x03 => "Breakpoint",
                0x04 => "Overflow",
                0x05 => "Bound Range",
                0x06 => "Invalid Opcode",
                0x07 => "Device Not Available",
                0x08 => "Double Fault",
                0x09 => "Coprocessor Segment Overrun",
                0x0A => "Invalid TSS",
                0x0B => "Segment not Present",
                0x0C => "Stack Fault",
                0x0D => "General Protection Fault",
                0x0E => "Page Fault",
                0x0F => "Reserved",
                0x10 => "x87 Floating Point",
                0x11 => "Alignment Check",
                0x12 => "Machine Check",
                0x13 => "SIMD Floating Point",
                0x14...0x1D => "Reserved",
                0x1E => "Security-sensitive event in Host",
                0x1F => "Reserved",
                else => "Unknown",
            }) });
            // virtio.printf("cpu state: {}\n", .{cpu_state});
            if (cpu_state.interrupt_number == 14) {
                var faulting_address: u32 = 0;
                asm volatile ("mov %cr2, %[faulting_address]"
                    : [faulting_address] "=r" (faulting_address),
                );
                virtio.printf("Page Fault when {s} address:0x{X:0>8} from {s}: {s}\n", .{
                    if ((cpu_state.error_code & 2) != 0) @as([]const u8, "writing") else @as([]const u8, "reading"),
                    faulting_address,
                    if ((cpu_state.error_code & 4) != 0) @as([]const u8, "userspace") else @as([]const u8, "kernelspace"),
                    if ((cpu_state.error_code & 1) != 0) @as([]const u8, "access denied") else @as([]const u8, "page unmapped"),
                });
                virtio.printf("Offending address:0x{X:0>8}\n", .{cpu_state.eip});
            }
        },
        else => {
            virtio.printf("interrupt has accured yippe? not exeption interrupt/exeption:{}, error:{}\n", .{ cpu_state.interrupt_number, cpu_state.error_code });
        },
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
                \\  call %[function:P]
                \\  add $4, %esp         // remove the pointer to the cpu state
                :
                : [function] "X" (function),
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
