const std = @import("std");
const idt = @import("idt.zig");

pub fn isrHandler(cpu_state: idt.CpuState) void {
    _ = cpu_state; // autofix

}
