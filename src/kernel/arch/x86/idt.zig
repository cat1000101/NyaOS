const std = @import("std");
const virtio = @import("virtio.zig");
const gdt = @import("gdt.zig");
const int = @import("interrupts.zig");
const pic = @import("pic.zig");

const TASK_GATE: u4 = 0x5;
const INTERRUPT_GATE_16: u4 = 0x6;
const TRAP_GATE_16: u4 = 0x7;
const INTERRUPT_GATE: u4 = 0xE;
const TRAP_GATE: u4 = 0xF;

pub const PRIVLIGE_RING_0: u2 = 0x0;
pub const PRIVLIGE_RING_1: u2 = 0x1;
pub const PRIVLIGE_RING_2: u2 = 0x2;
pub const PRIVLIGE_RING_3: u2 = 0x3;

pub const InterruptError = error{
    interruptOpen,
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

// TODO: this is a bug? change the oofset to pointer when fixed https://github.com/ziglang/zig/issues/21463
const Idtr = packed struct {
    size: u16, // size of the IDT in bytes - 1
    offset: u32, // *[256]IdtGateDescriptor, // address of the IDT (not the physical address, paging applies)
};

pub var idt: [256]IdtGateDescriptor = [_]IdtGateDescriptor{std.mem.zeroes(IdtGateDescriptor)} ** 256;
var idtr: Idtr = undefined;

pub fn initIdt() void {
    idtr = .{
        .size = @sizeOf(IdtGateDescriptor) * 256 - 1,
        .offset = @intFromPtr(&idt),
    };

    int.installIsr();

    pic.initPic();

    loadIdt(&idtr);
    virtio.printf("initialized idt\n", .{});
}

pub fn openIdtGate(index: usize, interrupt: *const fn () callconv(.Naked) void) InterruptError!void {
    if (idt[index].p == 1) return InterruptError.interruptOpen;
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

fn loadIdt(idtr_pointer: *const Idtr) void {
    // Load the IDT into the CPU
    asm volatile ("LIDT (%[idtr_pointer])"
        :
        : [idtr_pointer] "{eax}" (idtr_pointer),
        : "%eax"
    );
}
