const std = @import("std");
const idt = @import("idt.zig");
const int = @import("interrupts.zig");

pub fn isrHandler(cpu_state: *idt.CpuState) void {
    _ = cpu_state; // autofix
}

pub fn isrInit() void {
    comptime for (0..31) |num| {
        const interrupt = int.generateStub(num);
        idt.openIdtGate(num, &interrupt);
    };
}
