const std = @import("std");
const idt = @import("idt.zig");
const int = @import("interrupts.zig");
const virtio = @import("virtio.zig");

pub fn isrHandler(cpu_state: *idt.CpuState) void {
    _ = cpu_state; // autofix
}

pub fn isrInit() void {
    comptime var i = 0;
    inline while (i < 32) : (i += 1) {
        const interrupt = int.generateStub(i);
        idt.openIdtGate(i, &interrupt) catch |err| switch (err) {
            idt.InterruptError.interruptOpen => {
                virtio.outb("wtf did u do??????????\n");
            },
        };
    }

    virtio.outb("initialized isr\n");
}
