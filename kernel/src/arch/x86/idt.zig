const std = @import("std");
const debug = @import("debug.zig");
const gdt = @import("gdt.zig");
const int = @import("interrupts.zig");
const pic = @import("pic.zig");

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

const IdtGateDescriptor = packed struct {
    /// A 32-bit value, split in two parts. It represents the address of the entry point of the Interrupt Service Routine.
    offset_low: u16,
    /// A Segment Selector with multiple fields which must point to a valid code segment in your GDT.
    selector: u16,
    /// preserved not to be used or anything
    reserved: u8 = 0,
    /// A 4-bit value which defines the type of gate this Interrupt Descriptor represents
    type_attr: u4,
    /// must be zero
    zero: u1 = 0,
    /// A 2-bit value which defines the CPU Privilege Levels which are allowed to access this interrupt via the INT instruction
    dpl: u2,
    /// 1 if there is a thing here 0 if not
    p: u1,
    /// offset higher half
    offset_high: u16,
};

// TODO: this is a bug? change the oofset to pointer when fixed https://github.com/ziglang/zig/issues/21463
const Idtr = packed struct {
    /// size of the IDT in bytes - 1
    size: u16,
    /// *[256]IdtGateDescriptor, // address of the IDT (not the physical address, paging applies)
    offset: u32,
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
    debug.printf("initialized idt\n", .{});

    asm volatile ("int $1"); // test for the interrutps
}

pub fn openIdtGate(index: usize, interrupt: *const fn () callconv(.naked) void, gateType: u4, dpl: u2) InterruptError!void {
    if (idt[index].p == 1) return InterruptError.interruptOpen;
    setIdtGate(
        index,
        @intFromPtr(interrupt),
        gdt.KERNEL_CODE_OFFSET,
        gateType,
        dpl,
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
