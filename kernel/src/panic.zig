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
    var stackTrace = std.debug.StackIterator.init(@returnAddress(), @frameAddress());

    const kernelFile = files.open("kernel.elf", 0) catch |err| {
        log.err("couldn't open kernel elf file for dwarf {}\n", .{err});
        @trap();
    };

    const allocator = kmalloc.allocator();
    var dwarfInfo = dwarf.getSelfDwarf(allocator, kernelFile.file) catch |err| {
        log.err("couldn't get dwarf info {}\n", .{err});
        while (stackTrace.next()) |raddr| {
            log.err("  \x1B[90m0x{x:0>16}\x1B[0m\n", .{raddr});
        }
        @trap();
    };
    defer dwarfInfo.deinit(allocator);

    while (stackTrace.next()) |raddr| {
        dwarf.printSourceAtAddress(
            allocator,
            &dwarfInfo,
            raddr,
            &dwarf.sourceFiles,
        ) catch |err| {
            log.err("failed to print source at address: {}\n", .{err});
        };
    }

    log.err("panic finish\n", .{});
    @trap();
}
