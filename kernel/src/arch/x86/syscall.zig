const interrupts = @import("interrupts.zig");
const syscallUtil = @import("syscallUtil.zig");

const std = @import("std");
const debug = @import("debug.zig");

// the syscall arguments are passed in registers
// eax: syscall number
// ebx: arg0
// ecx: arg1
// edx: arg2
// esi: arg3
// edi: arg4
// ebp: arg5

pub export fn syscallHandler(context: *interrupts.CpuState) void {
    if (context.eax == 69) { // put string
        const printString: [*:0]u8 = @ptrFromInt(context.ebx);
        debug.printf("{s}\n", .{printString});
        context.eax = syscallUtil.SUCCESS_RETURN;
        return;
    } else if (context.eax == 420) { // put char
        debug.printf("{c}", .{@as(u8, @truncate(context.ebx))});
        context.eax = syscallUtil.SUCCESS_RETURN;
        return;
    } else if (context.eax == 69420) { // get frame and size in pixels and set the screen frame buffer to it
        context.eax = __syscall_set_framebuffer(@ptrFromInt(context.ebx), context.ecx);
        return;
    } else if (context.eax == 421) { // sleeb in ms
        pit.ksleep(context.ebx);
        return;
    } else if (context.eax == 422) { // get ms sience startup
        context.eax = pit.getTimeMs();
        debug.debugPrint("time sience start: {}\n", .{context.eax});
        return;
    }

    debug.debugPrint("\n", .{});
    debug.debugPrint("++syscall()\n", .{});
    defer {
        debug.debugPrint("--syscall()\n", .{});
        debug.debugPrint("\n", .{});
    }

    debug.debugPrint("syscall:  eax(syscall number): 0x{X:0>8},  ebx(arg0): 0x{X:0>8}\n", .{
        context.eax,
        context.ebx,
    });
    debug.debugPrint("syscall:  ecx(arg1):           0x{X:0>8},  edx(arg2): 0x{X:0>8}\n", .{
        context.ecx,
        context.edx,
    });
    debug.debugPrint("syscall:  esi(arg3):           0x{X:0>8},  edi(arg4): 0x{X:0>8}\n", .{
        context.esi,
        context.edi,
    });
    debug.debugPrint("syscall:  ebp(arg5):           0x{X:0>8},  syscall: {s}\n", .{
        context.ebp,
        if (context.eax <= 385 and context.eax >= 0) syscallUtil.syscallNames[context.eax] else "unknown",
    });
    debug.debugPrint("syscall:  eax(syscall number): 0x{X:0>8},  syscall: {s}\n", .{
        context.eax,
        if (context.eax <= 385 and context.eax >= 0) syscallUtil.syscallNames[context.eax] else "unknown",
    });

    if (context.eax == 0xF3) {
        context.eax = __syscall_set_thread_area(@ptrFromInt(context.ebx));
        return;
    } else if (context.eax == 0xC0) {
        context.eax = __syscall_mmap(context.ebx, context.ecx, context.edx, context.esi, context.edi, context.ebp);
        return;
    } else if (context.eax == 0x2D) {
        context.eax = __syscall_brk(context.ebx);
        return;
    } else if (context.eax == 0x5) {
        context.eax = __syscall_open(@ptrFromInt(context.ebx), context.ecx, context.edx);
        return;
    } else if (context.eax == 0x6) {
        context.eax = __syscall_close(context.ebx);
        return;
    } else if (context.eax == 0x91) {
        context.eax = __syscall_readv(context.ebx, @ptrFromInt(context.ecx), @bitCast(context.edx));
        return;
    } else if (context.eax == 0x92) {
        context.eax = __syscall_writev(context.ebx, @ptrFromInt(context.ecx), @bitCast(context.edx));
        return;
    } else if (context.eax == 0x8C) {
        context.eax = __syscall_llseek(context.ebx, context.ecx, context.edx, @ptrFromInt(context.esi), context.edi);
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

const pit = @import("pit.zig");
const tty = @import("../../drivers/tty.zig");
fn __syscall_set_framebuffer(framebuffer: ?[*]tty.FrameBuffer.Pixel, size: u32) u32 {
    debug.debugPrint("++__syscall_set_framebuffer()\n", .{});
    defer {
        debug.debugPrint("--__syscall_set_framebuffer()\n", .{});
    }
    if (framebuffer) |lframe| {
        const frameSlice = lframe[0..size];
        tty.framebuffer.flushWithFrame(frameSlice) catch |err| {
            debug.errorPrint("__syscall_set_framebuffer:  failed to flush framebuffer: {}\n", .{err});
            return syscallUtil.ERROR_RETURN;
        };
        return syscallUtil.SUCCESS_RETURN;
    } else {
        debug.errorPrint("__syscall_set_framebuffer:  framebuffer is null\n", .{});
        return syscallUtil.ERROR_RETURN;
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
        const retSlice = vmm.mapVirtualAddressRange(userThread.threadData.threadRandomHeap, llength) orelse {
            debug.errorPrint("__syscall_mmap:  failed to map virtual address range\n", .{});
            return syscallUtil.ERROR_RETURN;
        };
        const retaddr: u32 = @intFromPtr(retSlice.ptr);
        userThread.threadData.threadRandomHeap = retaddr + retSlice.len;
        debug.infoPrint("__syscall_mmap:  addr is null, allocated at: 0x{X} length: 0x{X}\n", .{ retaddr, retSlice.len });
        return retaddr;
    } else {
        const retSlice = vmm.mapVirtualAddressRange(addr, llength) orelse {
            debug.errorPrint("__syscall_mmap:  failed to map virtual address range\n", .{});
            return syscallUtil.ERROR_RETURN;
        };
        const retaddr: u32 = @intFromPtr(retSlice.ptr);
        debug.infoPrint("__syscall_mmap:  addr is not null, mapped at: 0x{X} length: 0x{X}\n", .{ retaddr, retSlice.len });
        return retaddr;
    }
}

fn __syscall_brk(addr: u32) u32 {
    debug.debugPrint("++__syscall_brk()\n", .{});
    defer {
        debug.debugPrint("--__syscall_brk()\n", .{});
    }

    if (addr == 0) {
        debug.infoPrint("__syscall_brk:  addr is null corrent break: 0x{X}\n", .{userThread.threadData.threadBreak});
        return userThread.threadData.threadBreak;
    } else if (addr >= memory.KERNEL_ADDRESS_SPACE) {
        debug.errorPrint("__syscall_brk:  it wanted to expand to kernel: 0x{X} nughty nughty\n", .{addr});
        return userThread.threadData.threadBreak;
    } else if (addr > userThread.threadData.threadBreak) {
        const alignedAddr = memory.alignAddressUp(addr, memory.PAGE_SIZE);
        const retSlice = vmm.mapVirtualAddressRange(userThread.threadData.threadBreak, alignedAddr - userThread.threadData.threadBreak) orelse {
            debug.errorPrint("__syscall_brk:  failed to allocate pages\n", .{});
            return userThread.threadData.threadBreak;
        };
        debug.infoPrint("__syscall_brk:  expand from 0x{X} to: 0x{X}\n", .{
            userThread.threadData.threadBreak,
            @intFromPtr(retSlice.ptr) + retSlice.len,
        });
        userThread.threadData.threadBreak = @intFromPtr(retSlice.ptr) + retSlice.len;
        return userThread.threadData.threadBreak;
    } else if (addr < userThread.threadData.threadBreak) {
        debug.infoPrint("__syscall_brk:  shrink from 0x{X} to: 0x{X}\n", .{
            userThread.threadData.threadBreak,
            addr,
        });
        const alignedAddr = memory.alignAddressUp(addr, memory.PAGE_SIZE);
        vmm.freePages(@ptrFromInt(alignedAddr), (userThread.threadData.threadBreak - alignedAddr) / memory.PAGE_SIZE) catch |err| {
            debug.errorPrint("__syscall_brk:  failed to free pages: {}\n", .{err});
            return userThread.threadData.threadBreak;
        };
        userThread.threadData.threadBreak = alignedAddr;
        return userThread.threadData.threadBreak;
    }
    return userThread.threadData.threadBreak;
}

// idk why i did this, but i did, was never called (oh i was looking at the wrong syscall table)
fn __syscall_truncate(path: ?[*]u8, length: u32) u32 {
    if (path) |lpath| {
        debug.debugPrint("truncate:  path: {s}\n", .{lpath[0..length]});
        return syscallUtil.SUCCESS_RETURN;
    } else {
        debug.debugPrint("__syscall_truncate:  path is null?\n", .{});
        return syscallUtil.SUCCESS_RETURN;
    }
}

const files = @import("../../mem/files.zig");

fn __syscall_open(path: ?[*:0]u8, flags: u32, mode: u32) u32 {
    _ = mode;
    debug.debugPrint("++__syscall_open()\n", .{});
    defer {
        debug.debugPrint("--__syscall_open()\n", .{});
    }
    if (path) |lpath| {
        debug.debugPrint("open:  path: {s}\n", .{lpath});
        const pathSlice = std.mem.span(lpath);
        const file = files.open(pathSlice, flags) catch |err| {
            debug.errorPrint("__syscall_open:  failed to open file: {}\n", .{err});
            return syscallUtil.ERROR_RETURN;
        };
        debug.infoPrint("__syscall_open:  opened file: {s} fd: {}\n", .{ pathSlice, file.fd });
        return file.fd;
    } else {
        debug.debugPrint("__syscall_open:  path is null?\n", .{});
        return syscallUtil.ERROR_RETURN;
    }
}

fn __syscall_close(fd: u32) u32 {
    debug.debugPrint("++__syscall_close()\n", .{});
    defer {
        debug.debugPrint("--__syscall_close()\n", .{});
    }
    if (fd > files.fds.len) {
        debug.errorPrint("__syscall_close:  fd is out of range\n", .{});
        return syscallUtil.ERROR_RETURN;
    }

    files.close(fd) catch |err| {
        debug.errorPrint("__syscall_close:  failed to close file: {}\n", .{err});
        return syscallUtil.ERROR_RETURN;
    };
    debug.infoPrint("__syscall_close:  closed file: {}\n", .{fd});
    return syscallUtil.SUCCESS_RETURN;
}

const OffsetType = enum(u32) {
    SEEK_SET = 0,
    SEEK_CUR = 1,
    SEEK_END = 2,
    _,
};

fn __syscall_llseek(fd: u32, offset_high: u32, offset_low: u32, result: ?*u64, whence: u32) u32 {
    debug.debugPrint("++__syscall_llseek()\n", .{});
    defer {
        debug.debugPrint("--__syscall_llseek()\n", .{});
    }
    if (fd > files.fds.len) {
        debug.errorPrint("__syscall_llseek:  fd is out of range\n", .{});
        return syscallUtil.ERROR_RETURN;
    }

    const returnPointer: *u64 = result orelse {
        debug.errorPrint("__syscall_llseek:  result is null\n", .{});
        return syscallUtil.ERROR_RETURN;
    };
    if (files.fds[fd]) |*file| {
        debug.debugPrint("llseek:  fd: {}, offset_high: 0x{X}, offset_low: 0x{X}, result: 0x{X}, whence: {}\n", .{
            file.fd,
            offset_high,
            offset_low,
            @intFromPtr(returnPointer),
            @as(OffsetType, @enumFromInt(whence)),
        });
        const offset: i64 = @bitCast(@as(u64, offset_high) << 32 | @as(u64, offset_low));
        if (@abs(offset) > file.file.len) {
            debug.errorPrint("__syscall_llseek:  offset is out of range\n", .{});
            return syscallUtil.ERROR_RETURN;
        }
        switch (@as(OffsetType, @enumFromInt(whence))) {
            OffsetType.SEEK_SET => {
                debug.debugPrint("llseek:  SEEK_SET\n", .{});
                if (offset < 0) {
                    debug.errorPrint("__syscall_llseek:  offset is negative\n", .{});
                    return syscallUtil.ERROR_RETURN;
                }
                file.offset = @intCast(offset);
                debug.debugPrint("__syscall_llseek:  set new offset: 0x{X}\n", .{file.offset});
            },
            OffsetType.SEEK_CUR => {
                debug.debugPrint("llseek:  SEEK_CUR\n", .{});
                if (offset + @as(i64, @intCast(file.offset)) < 0) {
                    debug.errorPrint("__syscall_llseek:  offset is negative\n", .{});
                    return syscallUtil.ERROR_RETURN;
                }
                const newOffset: u64 = @intCast(@as(i64, @intCast(file.offset)) + offset);
                file.offset = newOffset;
                debug.debugPrint("__syscall_llseek:  add to cur {} new offset: 0x{X}\n", .{ offset, file.offset });
            },
            OffsetType.SEEK_END => {
                debug.debugPrint("llseek:  SEEK_END\n", .{});
                if (offset > 0) {
                    debug.errorPrint("__syscall_llseek:  offset is positive\n", .{});
                    return syscallUtil.ERROR_RETURN;
                }
                file.offset = file.file.len - @abs(offset);
                debug.debugPrint("__syscall_llseek:  from the end {} new offset: 0x{X}\n", .{ offset, file.offset });
            },
            else => {
                debug.errorPrint("__syscall_llseek:  invalid whence\n", .{});
                return syscallUtil.ERROR_RETURN;
            },
        }
        returnPointer.* = file.offset;
        debug.debugPrint("__syscall_llseek:  return pointer content: 0x{X}\n", .{returnPointer.*});
        return syscallUtil.SUCCESS_RETURN;
    } else {
        debug.errorPrint("__syscall_llseek:  fd is not valid\n", .{});
        return syscallUtil.ERROR_RETURN;
    }
}

const IoVec = extern struct {
    iov_base: ?[*]u8,
    iov_len: isize,
};
fn __syscall_readv(fd: u32, iov: ?[*]IoVec, iovcnt: i32) u32 {
    debug.debugPrint("++__syscall_readv()\n", .{});
    defer {
        debug.debugPrint("--__syscall_readv()\n", .{});
    }
    if (fd > files.fds.len) {
        debug.errorPrint("__syscall_readv:  fd is out of range: {}\n", .{fd});
        return syscallUtil.ERROR_RETURN;
    }
    if (iovcnt <= 0) {
        debug.errorPrint("__syscall_readv:  iovcnt is below or equal 0: {}\n", .{iovcnt});
        return syscallUtil.ERROR_RETURN;
    }
    const liovcnt: u32 = @intCast(iovcnt);
    const file = files.fds[fd] orelse {
        debug.errorPrint("__syscall_readv:  fd is not valid: {}\n", .{fd});
        return syscallUtil.ERROR_RETURN;
    };
    const iovSlice: []IoVec = (iov orelse {
        debug.errorPrint("__syscall_readv:  iov is null\n", .{});
        return syscallUtil.ERROR_RETURN;
    })[0..liovcnt];
    var bytesRead: u32 = 0;
    for (iovSlice) |iovec| {
        if (iovec.iov_len <= 0) {
            debug.debugPrint("__syscall_readv:  iovec is empty or negetive: {}\n", .{iovec.iov_len});
            continue;
        }
        const iovecLength: usize = @intCast(iovec.iov_len);
        const writeSlice = (iovec.iov_base orelse {
            debug.errorPrint("__syscall_readv:  iovec base is null\n", .{});
            return syscallUtil.ERROR_RETURN;
        })[0..iovecLength];
        const readBytes = files.readWithOffset(fd, bytesRead, writeSlice) catch |err| {
            debug.errorPrint("__syscall_readv:  failed to read file: {}\n", .{err});
            return syscallUtil.ERROR_RETURN;
        };
        bytesRead += readBytes;
        if (readBytes < iovecLength) {
            debug.debugPrint("__syscall_readv:  reached end of file saj\n", .{});
            break;
        }
    }
    debug.debugPrint("__syscall_readv:  read 0x{X} bytes, from 0x{X} to 0x{X} in file, file size: 0x{X}\n", .{
        bytesRead,
        file.offset,
        file.offset + bytesRead,
        file.file.len,
    });
    return bytesRead;
}
fn __syscall_writev(fd: u32, iov: ?[*]IoVec, iovcnt: i32) u32 {
    debug.debugPrint("++__syscall_writev()\n", .{});
    defer {
        debug.debugPrint("--__syscall_writev()\n", .{});
    }
    if (fd > files.fds.len) {
        debug.errorPrint("__syscall_writev:  fd is out of range: {}\n", .{fd});
        return syscallUtil.ERROR_RETURN;
    }
    if (iovcnt <= 0) {
        debug.errorPrint("__syscall_writev:  iovcnt is below or equal 0: {}\n", .{iovcnt});
        return syscallUtil.ERROR_RETURN;
    }
    const liovcnt: u32 = @intCast(iovcnt);
    const file = files.fds[fd] orelse {
        debug.errorPrint("__syscall_readv:  fd is not valid: {}\n", .{fd});
        return syscallUtil.ERROR_RETURN;
    };
    const iovSlice: []IoVec = (iov orelse {
        debug.errorPrint("__syscall_writev:  iov is null\n", .{});
        return syscallUtil.ERROR_RETURN;
    })[0..liovcnt];
    var wroteBytes: u32 = 0;
    for (iovSlice) |iovec| {
        if (iovec.iov_len <= 0) {
            debug.debugPrint("__syscall_writev:  iovec is empty or negetive: {}\n", .{iovec.iov_len});
            continue;
        }
        const iovecLength: usize = @intCast(iovec.iov_len);
        const writeSlice = (iovec.iov_base orelse {
            debug.errorPrint("__syscall_readv:  iovec base is null\n", .{});
            return syscallUtil.ERROR_RETURN;
        })[0..iovecLength];
        const writeBytes = files.readWithOffset(fd, wroteBytes, writeSlice) catch |err| {
            debug.errorPrint("__syscall_readv:  failed to read file: {}\n", .{err});
            return syscallUtil.ERROR_RETURN;
        };
        wroteBytes += writeBytes;
        if (writeBytes < iovecLength) {
            debug.debugPrint("__syscall_readv:  reached end of file saj\n", .{});
            break;
        }
    }
    debug.debugPrint("__syscall_writev:  wrote 0x{X} bytes, from 0x{X} to 0x{X} in file, file size: 0x{X}\n", .{
        wroteBytes,
        file.offset,
        file.offset + wroteBytes,
        file.file.len,
    });
    return wroteBytes;
}
