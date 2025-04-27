const interrupts = @import("interrupts.zig");
const debug = @import("debug.zig");
const syscallUtil = @import("syscallUtil.zig");

// the syscall arguments are passed in registers
// eax: syscall number
// ebx: arg0
// ecx: arg1
// edx: arg2
// esi: arg3
// edi: arg4
// ebp: arg5

pub export fn syscallHandler(context: *interrupts.CpuState) void {
    debug.debugPrint("\n", .{});
    debug.debugPrint("++syscall()\n", .{});
    debug.infoPrint("\n", .{});
    defer {
        debug.infoPrint("\n", .{});
        debug.debugPrint("--syscall()\n", .{});
        debug.debugPrint("\n", .{});
    }

    if (context.eax == 69) {
        const printString: [*:0]u8 = @ptrFromInt(context.ebx);
        debug.printf("syscall print: {s}\n", .{printString});
        context.eax = syscallUtil.SUCCESS_RETURN;
        return;
    }

    debug.infoPrint("syscall:  eax(syscall number): 0x{X:0>8},  ebx(arg0): 0x{X:0>8}\n", .{
        context.eax,
        context.ebx,
    });
    debug.infoPrint("syscall:  ecx(arg1):           0x{X:0>8},  edx(arg2): 0x{X:0>8}\n", .{
        context.ecx,
        context.edx,
    });
    debug.infoPrint("syscall:  esi(arg3):           0x{X:0>8},  edi(arg4): 0x{X:0>8}\n", .{
        context.esi,
        context.edi,
    });
    debug.infoPrint("syscall:  ebp(arg5):           0x{X:0>8},  syscall: {s}\n", .{
        context.ebp,
        if (context.eax <= 385 and context.eax >= 0) syscallUtil.syscallNames[context.eax] else "unknown",
    });

    if (context.eax == 0xF3) {
        context.eax = __syscall_set_thread_area(@ptrFromInt(context.ebx));
        return;
    } else if (context.eax == 0xC0) {
        context.eax = __syscall_mmap(context.ebx, context.ecx, context.edx, context.esi, context.edi, context.ebp);
        return;
    } else if (context.eax == 0x5C) {
        context.eax = __syscall_truncate(@ptrFromInt(context.ebx), context.ecx);
        return;
    } else {
        debug.errorPrint("syscall:  not implumented syscall {s} number: 0x{X} \n", .{
            if (context.eax <= 385 and context.eax >= 0) syscallUtil.syscallNames[context.eax] else "unknown",
            context.eax,
        });
        context.eax = syscallUtil.ERROR_RETURN;
        return;
    }
}

const gdt = @import("gdt.zig");
const user_desc = extern struct {
    const EMPTY_FLAGS: u32 = 0b101000;
    entry_number: u32,
    base_addr: u32,
    limit: u32,
    bitfeild: packed struct(u32) {
        seg_32bit: u1,
        contents: u2,
        read_exec_only: u1,
        limit_in_pages: u1,
        seg_not_present: u1,
        useable: u1,
        padding: u25,
    },
};
fn __syscall_set_thread_area(userDesc: ?*user_desc) u32 {
    debug.debugPrint("++__syscall_set_thread_area()\n", .{});
    defer {
        debug.debugPrint("--__syscall_set_thread_area()\n", .{});
    }

    if (userDesc) |description| {
        debug.debugPrint("user_desc.entry_number = 0x{X}\n", .{description.entry_number});
        debug.debugPrint("user_desc.base_addr    = 0x{X}\n", .{description.base_addr});
        debug.debugPrint("user_desc.limit        = 0x{X}\n", .{description.limit});
        debug.debugPrint("user_desc.bitfeild     = {b}\n", .{@as(u32, @bitCast(description.bitfeild))});

        if (@as(u32, @bitCast(description.bitfeild)) == user_desc.EMPTY_FLAGS) {
            debug.debugPrint("user_desc is empty\n", .{});

            if (description.entry_number <= gdt.THREAD_TLS_END and description.entry_number >= gdt.THREAD_TLS_START) {
                gdt.setGdtGate(
                    description.entry_number,
                    0,
                    0,
                    .{},
                    .{},
                );
                debug.infoPrint("set_thread_area:  set empty gdt entry in entry: #{}\n", .{description.entry_number});
                return syscallUtil.SUCCESS_RETURN;
            } else {
                debug.errorPrint("__syscall_set_thread_area:  user_desc entry number is out of range\n", .{});
                return syscallUtil.ERROR_RETURN;
            }
        } else if (description.entry_number <= gdt.THREAD_TLS_END and description.entry_number >= gdt.THREAD_TLS_START) {
            debug.debugPrint("user_desc entry number is in range\n", .{});

            gdt.setGdtGate(
                description.entry_number,
                description.base_addr,
                @truncate(description.limit),
                .{
                    .p = ~description.bitfeild.seg_not_present,
                    .dpl = 3,
                    .s = 1,
                    .e = description.bitfeild.read_exec_only,
                    .rw = ~description.bitfeild.read_exec_only,
                },
                .{
                    .g = description.bitfeild.limit_in_pages,
                    .db = description.bitfeild.seg_32bit,
                },
            );
            debug.infoPrint("set_thread_area:  set entry: #{}, gdt entry {}\n", .{
                gdt.getGdtEntry(description.entry_number),
                description.entry_number,
            });
            return syscallUtil.SUCCESS_RETURN;
        } else if (description.entry_number == 0xFFFFFFFF) {
            debug.debugPrint("user_desc entry number is 0xFFFFFFFF(-1) also means i chose\n", .{});

            for (gdt.THREAD_TLS_START..gdt.THREAD_TLS_END) |i| {
                if (!gdt.isEntryPresent(i)) {
                    gdt.setGdtGate(
                        i,
                        description.base_addr,
                        @truncate(description.limit),
                        .{
                            .p = ~description.bitfeild.seg_not_present,
                            .dpl = 3,
                            .s = 1,
                            .e = description.bitfeild.read_exec_only,
                            .rw = ~description.bitfeild.read_exec_only,
                        },
                        .{
                            .g = description.bitfeild.limit_in_pages,
                            .db = description.bitfeild.seg_32bit,
                        },
                    );
                    description.entry_number = i;
                    debug.infoPrint("set_thread_area:  set chosen entry: #{}, gdt entry {}\n", .{
                        gdt.getGdtEntry(description.entry_number),
                        description.entry_number,
                    });
                    return syscallUtil.SUCCESS_RETURN;
                }
            }
            return syscallUtil.ERROR_RETURN;
        } else {
            debug.errorPrint("__syscall_set_thread_area:  user_desc entry number is out of range\n", .{});
            return syscallUtil.ERROR_RETURN;
        }
    } else {
        debug.errorPrint("__syscall_set_thread_area:  user_desc is null\n", .{});
        return syscallUtil.ERROR_RETURN;
    }
}

const vmm = @import("../../mem/vmm.zig");
const memory = @import("../../mem/memory.zig");
const userThread = @import("userLand.zig");
const mmap_prot = enum(u32) {
    PROT_READ = 0x1, // Page can be read
    PROT_WRITE = 0x2, // Page can be written
    PROT_EXEC = 0x4, // Page can be executed
    PROT_NONE = 0x0, // Page cannot be accessed
}; // we dont use protection
const mmap_flags = enum(u32) {
    MAP_SHARED = 0x01, // Share this mapping
    MAP_PRIVATE = 0x02, // Changes are private
    MAP_FIXED = 0x10, // Interpret addr exactly
    MAP_ANONYMOUS = 0x20, // Don't use a file
};
fn __syscall_mmap(addr: u32, length: u32, prot: u32, flags: u32, fd: u32, pgoffset: u32) u32 {
    debug.debugPrint("++__syscall_mmap()\n", .{});
    defer {
        debug.debugPrint("--__syscall_mmap()\n", .{});
    }
    _ = prot;
    _ = flags;
    _ = pgoffset;
    if (length == 0) {
        debug.errorPrint("__syscall_mmap:  length is 0\n", .{});
        return syscallUtil.ERROR_RETURN;
    }
    const llength: u32 = memory.alignAddressUp(length, memory.PAGE_SIZE);

    if (fd != 0xFFFFFFFF) {
        debug.errorPrint("__syscall_mmap:  fd is not -1 i dont support file rn\n", .{});
        return syscallUtil.ERROR_RETURN;
    }
    if (addr == 0) {
        const retSlice = vmm.mapVirtualAddressRange(userThread.threadData.threadBreak, llength) orelse {
            debug.errorPrint("__syscall_mmap:  failed to map virtual address range\n", .{});
            return syscallUtil.ERROR_RETURN;
        };
        const retaddr: u32 = @intFromPtr(retSlice.ptr);
        userThread.threadData.threadBreak = retaddr + retSlice.len;
        debug.infoPrint("mmap:  addr is null, allocated at: 0x{X} length: 0x{X}\n", .{ retaddr, retSlice.len });
        return retaddr;
    } else {
        const retSlice = vmm.mapVirtualAddressRange(addr, llength) orelse {
            debug.errorPrint("__syscall_mmap:  failed to map virtual address range\n", .{});
            return syscallUtil.ERROR_RETURN;
        };
        const retaddr: u32 = @intFromPtr(retSlice.ptr);
        debug.infoPrint("mmap:  addr is not null, mapped at: 0x{X} length: 0x{X}\n", .{ retaddr, retSlice.len });
        return retaddr;
    }
}

// fn __syscall_brk(addr: u32) u32 {}
// else if (context.eax == 0x2D) {
//         // context.eax = __syscall_brk(context.ebx);
//         context.eax = syscallUtil.ERROR_RETURN;
//         return;
//     }

// idk why i did this, but i did, was never called
fn __syscall_truncate(path: ?[*]u8, length: u32) u32 {
    if (path) |lpath| {
        debug.debugPrint("truncate:  path: {s}\n", .{lpath[0..length]});
        return syscallUtil.SUCCESS_RETURN;
    } else {
        debug.debugPrint("__syscall_truncate:  path is null?\n", .{});
        return syscallUtil.SUCCESS_RETURN;
    }
}
