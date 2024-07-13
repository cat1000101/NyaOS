const std = @import("std");
const virtio = @import("virtio.zig");

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
    offset: u32, // address of the IDT (not the physical address, paging applies)
};

var idtr: Idtr = undefined;
var idt = [_]IdtGateDescriptor{std.mem.zeroes(IdtGateDescriptor)} ** 256;

pub fn initIdt() void {
    idtr = .{
        .size = @sizeOf(IdtGateDescriptor) * 256 - 1,
        .offset = @intFromPtr(&idt),
    };

    loadIdt(&idtr);

    virtio.outb("initialized idt");
}

fn loadIdt(idtr_pointer: *Idtr) void {
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
