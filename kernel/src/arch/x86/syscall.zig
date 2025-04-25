const interrupts = @import("interrupts.zig");
const debug = @import("debug.zig");

pub export fn syscallHandler(context: *interrupts.CpuState) void {
    if (context.eax == 69) {
        const printString: [*:0]u8 = @ptrFromInt(context.ebx);
        debug.printf("syscall print: {s}", .{printString});
    }
    debug.infoPrint("cpu state after syscalls: {any}\n", .{context});
}
