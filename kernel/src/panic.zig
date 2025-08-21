const debug = @import("arch/x86/debug.zig");
const dwarf = @import("dwarf.zig");
const kmalloc = @import("mem/kmalloc.zig");
const files = @import("mem/files.zig");
const entry = @import("entry.zig");

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

    log.err("return address: 0x{X} frame address: 0x{X}\n", .{ @returnAddress(), @frameAddress() });
    log.err("stack starts at: 0x{X} end: 0x{X}\n", .{
        @intFromPtr(&entry.stack[0]),
        @intFromPtr(&entry.stack[0]) + entry.stack.len,
    });
    var si = std.debug.StackIterator.init(@returnAddress(), @frameAddress());
    const allocator = kmalloc.allocator();

    dwarf.stackIteratorTrace(&si, allocator);

    log.err("panic finish\n", .{});
    @trap();
}
