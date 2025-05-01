const archDebug = @import("arch/x86/debug.zig");

const std = @import("std");
const log = std.log;

pub const panic = std.debug.FullPanic(panicHandler);
var doublePanic: bool = false;

pub fn panicHandler(msg: []const u8, ra: ?usize) noreturn {
    @branchHint(.cold);
    _ = ra;

    if (doublePanic) @trap();
    doublePanic = true;

    log.err("PANIC: {s}\n", .{msg});

    var stack = std.debug.StackIterator.init(@returnAddress(), @frameAddress());
    while (stack.next()) |address| {
        log.err("???:?:?: 0x{x:0>16} in ??? (???)\n", .{address});
    }

    archDebug.print(msg);
    @trap();
}

// pub fn print_stack_trace(logger: anytype, ip: ?usize, trace: *std.builtin.StackTrace) void {
//     var i: usize = 0;
//     if (ip) |rip| {
//         logger.debug("   at   {d: <4}: {x:0>16}", .{ i, fixup_stack_addr(rip) });
//         i += 1;
//     }
//     var frame_index: usize = 0;
//     var frames_left: usize = @min(trace.index, trace.instruction_addresses.len);
//     while (frames_left != 0) : ({
//         frames_left -= 1;
//         frame_index = (frame_index + 1) % trace.instruction_addresses.len;
//         i += 1;
//     }) {
//         const return_address = fixup_stack_addr(trace.instruction_addresses[frame_index]);
//         logger.debug("   at   {d: <4}: {x:0>16}", .{ i, return_address });
//     }
// }

// pub fn dump_stack_trace(logger: anytype, ret_addr: ?usize) void {
//     logger.debug("current stack trace: ", .{});
//     var addrs: [16]usize = undefined;
//     var trace: std.builtin.StackTrace = .{
//         .instruction_addresses = &addrs,
//         .index = 0,
//     };
//     std.debug.captureStackTrace(null, &trace);
//     print_stack_trace(logger, ret_addr orelse @returnAddress(), &trace);
// }
