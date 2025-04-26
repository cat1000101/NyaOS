const interrupts = @import("interrupts.zig");
const debug = @import("debug.zig");

const ERROR_RETURN: u32 = 0xFFFFFFFF; // -1
const SUCCESS_RETURN: u32 = 0x00000000; // 0

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
    debug.debugPrint("\n", .{});
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
    defer {
        debug.debugPrint("\n", .{});
        debug.debugPrint("--syscall()\n", .{});
        debug.debugPrint("\n", .{});
    }

    if (context.eax == 69) {
        const printString: [*:0]u8 = @ptrFromInt(context.ebx);
        debug.printf("syscall print: {s}\n", .{printString});
        context.eax = SUCCESS_RETURN;
        return;
    }
    if (context.eax == 0xF3) {
        context.eax = __syscall_set_thread_area(@ptrFromInt(context.ebx));
        return;
    }

    context.eax = ERROR_RETURN;
    return;
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
    debug.debugPrint("\n", .{});
    debug.debugPrint("++__syscall_set_thread_area()\n", .{});
    debug.debugPrint("\n", .{});
    defer {
        debug.debugPrint("\n", .{});
        debug.debugPrint("--__syscall_set_thread_area()\n", .{});
        debug.debugPrint("\n", .{});
    }

    if (userDesc) |description| {
        debug.debugPrint("\n", .{});
        debug.debugPrint("user_desc.entry_number = 0x{X}\n", .{description.entry_number});
        debug.debugPrint("user_desc.base_addr    = 0x{X}\n", .{description.base_addr});
        debug.debugPrint("user_desc.limit        = 0x{X}\n", .{description.limit});
        debug.debugPrint("user_desc.bitfeild     = {b}\n", .{@as(u32, @bitCast(description.bitfeild))});
        debug.debugPrint("\n", .{});

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
                return SUCCESS_RETURN;
            } else {
                debug.errorPrint("__syscall_set_thread_area:  user_desc entry number is out of range\n", .{});
                return ERROR_RETURN;
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
            return SUCCESS_RETURN;
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
                    return SUCCESS_RETURN;
                }
            }
            return ERROR_RETURN;
        } else {
            debug.errorPrint("__syscall_set_thread_area:  user_desc entry number is out of range\n", .{});
            return ERROR_RETURN;
        }
    } else {
        debug.errorPrint("__syscall_set_thread_area:  user_desc is null\n", .{});
        return ERROR_RETURN;
    }
}
