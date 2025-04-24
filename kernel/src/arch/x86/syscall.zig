const interrupts = @import("interrupts.zig");
const debug = @import("debug.zig");

pub export fn syscallHandler(context: *interrupts.CpuState) void {
    debug.infoPrint("cpu state after syscalls: {any}\n", .{context});
}
