const idt = @import("idt.zig");
const paging = @import("paging.zig");
const syscall = @import("syscall.zig");

const std = @import("std");
const log = std.log;

export fn Handler(cpu_state: *ExeptionCpuState) void {
    switch (cpu_state.interrupt_number) {
        0x00...0x1F => {
            // half stolen thing for the printing: https://github.com/Ashet-Technologies/Ashet-OS/blob/9b595e38815dcc1ed1f7e20abd44ab43c1a63012/src/kernel/port/platform/x86/idt.zig#L67
            log.err("Unhandled exception 0x{X}: {s}, error code: 0x{X}/{b}\n", .{
                cpu_state.interrupt_number,
                @as([]const u8, switch (cpu_state.interrupt_number) {
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
                }),
                cpu_state.error_code,
                cpu_state.error_code,
            });
            log.debug("cpu state: {}\n", .{cpu_state});
            if (cpu_state.interrupt_number == 0xE) {
                var faulting_address: u32 = 0;
                asm volatile ("mov %cr2, %[faulting_address]"
                    : [faulting_address] "=r" (faulting_address),
                );
                log.err("Page Fault when {s} address:0x{X:0>8} from {s}: {s}, error: {b:0>32}\n", .{
                    if ((cpu_state.error_code & 2) != 0) @as([]const u8, "writing") else @as([]const u8, "reading"),
                    faulting_address,
                    if ((cpu_state.error_code & 4) != 0) @as([]const u8, "userspace") else @as([]const u8, "kernelspace"),
                    if ((cpu_state.error_code & 1) != 0) @as([]const u8, "access denied") else @as([]const u8, "page unmapped"),
                    cpu_state.error_code,
                });
                log.err("Offending location address(eip):0x{X:0>8}\n", .{cpu_state.eip});

                log.err("offending page directory entry: {any}\n", .{
                    paging.getPageDirectoryEntryRecursivly(faulting_address >> 22),
                });
                log.err("offending page table entry: {any}\n", .{
                    paging.getPageTableEntryRecursivly(faulting_address >> 22, (faulting_address >> 12) & 0x3FF),
                });
            }
            hlt(); // remember to remove this ====================================================================
        },
        else => {
            log.err("interrupt has accured yippe? not exeption. interrupt:{}, error:{}\n", .{ cpu_state.interrupt_number, cpu_state.error_code });
        },
    }
}

// cpu state when calling isr intrupt
pub const ExeptionCpuState = extern struct {
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

    // Items pushed by the CPU if a privilege level change occurs ¯\_(ツ)_/¯
    eip: u32,
    cs: u32,
    eflags: u32,
    user_esp: u32, // ESP if there is a privilege level change
    ss: u32, // SS if there is a privilege level change
};

export fn ExeptionCommonStub() callconv(.naked) void {
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
        ::: "eax", "esp");

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
        : "eax", "esp", "ds", "es", "fs", "gs"
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
        ::: "eax", "esp", "ds", "es", "fs", "gs");
}

// stollen/"inspired" from https://github.com/ZystemOS/pluto
// that is a good refrence for good practive maybe idk
fn generateExeptionStub(comptime interrupt_num: u32) fn () callconv(.naked) void {
    return struct {
        fn func() callconv(.naked) void {
            asm volatile (
                \\ cli
            );

            // These interrupts don't push an error code onto the stack, so will push a zero. meanng 0-31 other then those
            if (interrupt_num != 8 and !(interrupt_num >= 10 and interrupt_num <= 14) and interrupt_num != 17) {
                asm volatile (
                    \\ pushl $0
                    ::: "esp");
            }

            asm volatile (
                \\ pushl %[nr]
                \\ jmp %[ExeptionCommonStub:P]
                :
                : [nr] "n" (interrupt_num),
                  [ExeptionCommonStub] "X" (&ExeptionCommonStub),
                : "esp"
            );
        }
    }.func;
}

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

    // Items pushed by the CPU if a privilege level change occurs ¯\_(ツ)_/¯
    eip: u32,
    cs: u32,
    eflags: u32,
    user_esp: u32,
    ss: u32,
};

pub fn generateStub(function: *const fn (*CpuState) callconv(.c) void) fn () callconv(.naked) void {
    return struct {
        fn func() callconv(.naked) void {
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
                ::: "eax", "esp");

            // this place now is black boxed wawwie
            asm volatile (
                \\  mov $0x10, %ax       // use kernel data segment
                \\  mov %ax, %ds
                \\  mov %ax, %es
                \\  mov %ax, %fs
                \\  mov %ax, %gs
                ::: "eax", "ds", "es", "fs", "gs");

            asm volatile (
                \\  push %esp            // pass pointer to the cpu state
                \\  call %[function:P]
                \\  add $4, %esp         // remove the pointer to the cpu state
                :
                : [function] "X" (function),
                : "esp"
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
                ::: "eax", "esp", "ds", "es", "fs", "gs");
        }
    }.func;
}

pub fn installIsr() void {
    comptime var i = 0;
    inline while (i < 32) : (i += 1) {
        const interrupt = generateExeptionStub(i);
        idt.openIdtGate(i, &interrupt, idt.TRAP_GATE, idt.PRIVLIGE_RING_3) catch |err| switch (err) {
            idt.InterruptError.interruptOpen => {
                log.err("wtf did u do??????????(isr interrupt already open)\n", .{});
            },
        };
    }

    const syscallHand = generateStub(&syscall.syscallHandler);
    idt.openIdtGate(0x80, &syscallHand, idt.TRAP_GATE, idt.PRIVLIGE_RING_3) catch |err| {
        log.err("wtf did u do??????????(cant put the syscall thingy) error: {}\n", .{err});
    };

    log.info("installed isr\n", .{});
}

pub inline fn cli() void {
    asm volatile (
        \\ cli
    );
}
pub inline fn sti() void {
    asm volatile (
        \\ sti
    );
}
pub inline fn hlt() void {
    asm volatile (
        \\ hlt
    );
}
