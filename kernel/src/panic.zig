const debug = @import("arch/x86/debug.zig");
const dwarf = @import("dwarf.zig");
const kmalloc = @import("mem/kmalloc.zig");
const files = @import("mem/files.zig");

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

    const kernelFile = files.open("kernel.elf", 0) catch |err| {
        log.err("couldn't open kernel elf file for dwarf {}\n", .{err});
        @trap();
    };

    const allocator = kmalloc.allocator();
    var dwarfInfo = dwarf.getSelfDwarf(allocator, kernelFile.file) catch |err| {
        log.err("couldn't get dwarf info {}\n", .{err});
        while (stack.next()) |raddr| {
            log.err("  \x1B[90m0x{x:0>16}\x1B[0m\n", .{raddr});
        }
        @trap();
    };
    defer dwarfInfo.deinit(allocator);

    while (stack.next()) |raddr| {
        try dwarf.printSourceAtAddress(
            allocator,
            &dwarfInfo,
            raddr,
            &dwarf.sourceFiles,
        );
    }

    @trap();
}
