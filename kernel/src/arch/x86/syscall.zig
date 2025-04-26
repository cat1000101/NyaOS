const interrupts = @import("interrupts.zig");
const debug = @import("debug.zig");

pub export fn syscallHandler(context: *interrupts.CpuState) void {
    if (context.eax == 69) {
        const printString: [*:0]u8 = @ptrFromInt(context.ebx);
        debug.printf("syscall print: {s}\n", .{printString});
    }
    debug.infoPrint("syscall:  eax(syscall number): 0x{X:0>8},  ebx(arg0): 0x{X:0>8}\n", .{
        context.eax,
        context.ebx,
    });
    debug.infoPrint("syscall:  ecx(arg1): 0x{X:0>8},            edx(arg2): 0x{X:0>8}\n", .{
        context.ecx,
        context.edx,
    });
    debug.infoPrint("syscall:  esi(arg3): 0x{X:0>8},            edi(arg4): 0x{X:0>8}\n", .{
        context.esi,
        context.edi,
    });
    // debug.infoPrint("cpu state after syscalls: {any}\n", .{context});
}
