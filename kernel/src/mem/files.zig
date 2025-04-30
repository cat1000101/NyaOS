const multiboot = @import("../multiboot.zig");
const paging = @import("../arch/x86/paging.zig");
const vmm = @import("vmm.zig");
const memory = @import("memory.zig");
const userLand = @import("../arch/x86/userLand.zig");

const debug = @import("../arch/x86/debug.zig");
const std = @import("std");
const log = std.log;

pub const Fd = struct {
    fd: u32,
    file: []u8,
    offset: u64 = 0,
};

pub var fds: [16]?Fd = [_]?Fd{null} ** 16;
var corrent_fd: u32 = 3;

pub const FileError = error{
    ModuleNotFound,
    FileNotFound,
    InvalidFileDescriptor,
    InvalidFileOffset,
};

pub fn open(path: []const u8, flags: u32) !Fd {
    _ = flags;
    const files = multiboot.getModuleInfo() orelse return FileError.ModuleNotFound;
    for (files) |file| {
        const name = @as([*:0]u8, @ptrFromInt(file.cmdline));
        if (std.mem.eql(u8, std.mem.span(name), path)) {
            const fileSlice = loadFile(file) catch |err| {
                log.err("files.open:  failed to load file: {}\n", .{err});
                return err;
            };
            fds[corrent_fd] = Fd{
                .file = fileSlice,
                .fd = corrent_fd,
            };
            log.info("opened file: {s}, from 0x{X} to 0x{X} size: 0x{X} fd: {}\n", .{
                path,
                file.mod_start,
                @intFromPtr(fileSlice.ptr),
                fileSlice.len,
                corrent_fd,
            });
            corrent_fd += 1;
            return fds[corrent_fd - 1].?;
        }
    }
    return FileError.FileNotFound;
}

fn loadFile(mod: multiboot.multiboot_mod_list) ![]u8 {
    const fileSize = mod.mod_end - mod.mod_start;
    const fileSizeAligned = memory.alignAddressUp(fileSize, memory.PAGE_SIZE);
    paging.idPagesRecursivly(userLand.fileMaps, mod.mod_start, fileSizeAligned, true) catch |err| {
        log.err("files.loadFile:  couldn't load file to memory: {}\n", .{err});
        return err;
    };
    const file: []u8 = @as([*]u8, @ptrFromInt(userLand.fileMaps))[0..fileSize];
    userLand.fileMaps += fileSizeAligned;
    return file;
}

pub fn close(fd: u32) !void {
    if (fds[fd]) |file| {
        log.info("closing fd: {}\n", .{fd});
        const sizeAligned = memory.alignAddressUp(file.file.len, memory.PAGE_SIZE);
        paging.unMap(@intFromPtr(file.file.ptr), sizeAligned) catch |err| {
            log.err("files.close:  couldn't free file memory: {}\n", .{err});
            return err;
        };
        if (corrent_fd - 1 == fd) {
            corrent_fd -= 1;
        }
        if (@intFromPtr(file.file.ptr) + sizeAligned == userLand.fileMaps) {
            userLand.fileMaps -= sizeAligned;
            log.debug("deallocated file memory: 0x{X} size: 0x{X}\n", .{
                @intFromPtr(file.file.ptr),
                sizeAligned,
            });
        }
        fds[fd] = null;
        log.debug("closed fd: {} and deallocated it\n", .{fd});
    } else {
        return FileError.InvalidFileDescriptor;
    }
}

/// need to fix the offset being too big
pub fn readWithOffset(fd: u32, offset: u64, buffer: []u8) !u32 {
    if (fds[fd]) |file| {
        const addWithOverFlow = @addWithOverflow(offset, file.offset);
        if (addWithOverFlow[1] == 1 or addWithOverFlow[0] >= file.file.len) {
            return FileError.InvalidFileOffset;
        }
        const loffset: usize = @truncate(addWithOverFlow[0]);
        var readBytes = file.file.len - loffset;
        if (readBytes > buffer.len) {
            log.debug("buffer smaller then file. bytes in file after offset: {} in buffer: {}\n", .{ readBytes, buffer.len });
            readBytes = buffer.len;
        }
        const bufferSlice = buffer[0..readBytes];
        const fileSlice = file.file[loffset .. loffset + readBytes];
        log.debug("readWithOverflow:  offset: {} readBytes: {} buffer length: {}\n", .{
            addWithOverFlow[0],
            readBytes,
            buffer.len,
        });
        @memcpy(bufferSlice, fileSlice);
        return readBytes;
    } else {
        return FileError.InvalidFileDescriptor;
    }
}

/// need to fix the offset being too big
pub fn writeWithOffset(fd: u32, offset: u64, buffer: []u8) !u32 {
    if (fds[fd]) |file| {
        const addWithOverFlow = @addWithOverflow(offset, file.offset);
        if (addWithOverFlow[1] or addWithOverFlow[0] >= file.file.len) {
            return FileError.InvalidFileOffset;
        }
        var writeBytes = file.file.len - addWithOverFlow[0];
        if (writeBytes > buffer.len) {
            log.debug("file smaller then buffer. bytes in file after offset: {} in buffer: {}\n", .{ writeBytes, buffer.len });
            writeBytes = buffer.len;
        }
        const bufferSlice = buffer[0..writeBytes];
        const fileSlice = file.file[addWithOverFlow[0] .. addWithOverFlow[0] + writeBytes];
        log.debug("writeWithOverflow:  offset: {} writeBytes: {} buffer length: {}\n", .{
            addWithOverFlow[0],
            writeBytes,
            buffer.len,
        });
        @memcpy(fileSlice, bufferSlice);
        return writeBytes;
    } else {
        return FileError.InvalidFileDescriptor;
    }
}
