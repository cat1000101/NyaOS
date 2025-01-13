const std = @import("std");
const virtio = @import("virtio.zig");
const gdt = @import("gdt.zig");
const int = @import("interrupts.zig");

pub const TASK_GATE: u4 = 0x5;
pub const INTERRUPT_GATE_16: u4 = 0x6;
pub const TRAP_GATE_16: u4 = 0x7;
pub const INTERRUPT_GATE: u4 = 0xE;
pub const TRAP_GATE: u4 = 0xF;

pub const PRIVLIGE_RING_0: u2 = 0x0;
pub const PRIVLIGE_RING_1: u2 = 0x1;
pub const PRIVLIGE_RING_2: u2 = 0x2;
pub const PRIVLIGE_RING_3: u2 = 0x3;

pub const InterruptError = error{
    interruptOpen,
};

// cpu state when calling intrupt
pub const CpuState = packed struct {
    // General-purpose registers pushed by pusha
    edi: u32,
    esi: u32,
    ebp: u32,
    esp: u32,
    ebx: u32,
    edx: u32,
    ecx: u32,
    eax: u32,

    // Segment registers pushed manually
    gs: u16,
    fs: u16,
    es: u16,
    ds: u16,

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

const IdtGateDescriptor = packed struct {
    offset_low: u16, // Offset: A 32-bit value, split in two parts. It represents the address of the entry point of the Interrupt Service Routine.
    selector: u16, // Selector: A Segment Selector with multiple fields which must point to a valid code segment in your GDT.
    reserved: u8 = 0, // preserved
    type_attr: u4, // Gate Type: A 4-bit value which defines the type of gate this Interrupt Descriptor represents
    zero: u1 = 0, // must be zero
    dpl: u2, // DPL: A 2-bit value which defines the CPU Privilege Levels which are allowed to access this interrupt via the INT instruction
    p: u1, // 1 if there is a thing here 0 if not
    offset_high: u16, // offset higher half
};

const Idtr = packed struct {
    size: u16, // size of the IDT in bytes - 1
    offset: *[256]IdtGateDescriptor, // address of the IDT (not the physical address, paging applies)
};

var idtr: Idtr = undefined;
var idt: [256]IdtGateDescriptor = [_]IdtGateDescriptor{std.mem.zeroes(IdtGateDescriptor)} ** 256;

pub fn initIdt() void {
    idtr = .{
        .size = @sizeOf(IdtGateDescriptor) * 256 - 1,
        .offset = &idt,
    };

    loadIdt(&idtr);
    virtio.outb("initialized idt\n");
}

pub fn openIdtGate(index: usize, interrupt: *const fn () callconv(.Naked) void) InterruptError!void {
    if (idt[index].p == 1) return InterruptError.interruptOpen;
    virtio.printf("opening idt gate: {} {}\n", .{ index, interrupt });
    setIdtGate(
        index,
        @intFromPtr(interrupt),
        gdt.KERNEL_CODE_OFFSET,
        TRAP_GATE,
        PRIVLIGE_RING_3,
    );
}

fn setIdtGate(id: usize, offset: u32, selector: u16, gate_type: u4, dpl: u2) void {
    idt[id].dpl = dpl;
    idt[id].selector = selector;
    idt[id].type_attr = gate_type;
    idt[id].p = 1;
    idt[id].offset_low = @truncate(offset);
    idt[id].offset_high = @truncate(offset >> 16);
}

pub fn loadIdt(idtr_pointer: *const Idtr) void {
    // Load the GDT into the CPU
    asm volatile ("LIDT (%%eax)"
        :
        : [idtr_pointer] "{eax}" (idtr_pointer),
        : "%eax"
    );
}

test "idt" {
    std.debug.print("{any}", .{idt});
}
