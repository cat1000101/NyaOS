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
