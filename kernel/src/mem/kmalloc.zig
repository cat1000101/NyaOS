const std = @import("std");
const mem = std.mem;

const vmm = @import("vmm.zig");
const memory = @import("memory.zig");

const log = @import("std").log;

const blockHeader = struct {
    size: usize,
    isFree: bool,
    next: ?*blockHeader,
    prev: ?*blockHeader,
};
const blockHeaderSize: usize = @sizeOf(blockHeader);
const blockHeaderAlign: usize = @alignOf(blockHeader);

fn alignUp(size: usize) usize {
    return (size + blockHeaderAlign - 1) & ~(blockHeaderAlign - 1);
}

var kmallocHead: ?*blockHeader = null;
var kmallocSize: usize = 0;

pub fn kmalloc(size: usize) ?[*]u8 {
    if (size == 0) {
        log.err("kmalloc:  size is 0\n", .{});
        return null;
    }
    const alignedSize = alignUp(size);
    var current: ?*blockHeader = kmallocHead;
    while (current) |block| {
        if (block.isFree and block.size >= (alignedSize + blockHeaderSize)) {
            const newBlock: *blockHeader = @ptrFromInt(@intFromPtr(block) + alignedSize + blockHeaderSize);
            newBlock.* = .{
                .size = block.size - alignedSize - blockHeaderSize,
                .isFree = true,
                .next = block.next,
                .prev = block,
            };
            block.isFree = false;
            block.size = alignedSize;
            block.next = newBlock;
            log.debug("kmalloc:  allocated memory at: 0x{X} size: 0x{X} block address: 0x{X}\n", .{
                @intFromPtr(block) + blockHeaderSize,
                alignedSize,
                @intFromPtr(block),
            });
            return @ptrFromInt(@intFromPtr(block) + blockHeaderSize);
        }
        current = block.next;
    }
    log.err("kmalloc:  no free block found, TODO: allocating new page\n", .{});
    return null;
}

pub fn kfree(ptr: [*]u8) void {
    const block: *blockHeader = @ptrFromInt(@intFromPtr(ptr) - blockHeaderSize);
    if (block.isFree) {
        log.err("kfree:  block is already free\n", .{});
        return;
    }
    block.isFree = true;
    log.debug("kfree:  freed memory at: 0x{X} size: 0x{X}\n", .{
        @intFromPtr(ptr),
        block.size,
    });

    if (block.next) |nextBlock| {
        if (nextBlock.isFree) {
            block.size += nextBlock.size + blockHeaderSize;
            block.next = nextBlock.next;
            nextBlock.prev = block;
            nextBlock.size = undefined;
        }
    }
    if (block.prev) |prevBlock| {
        if (prevBlock.isFree) {
            prevBlock.size += block.size + blockHeaderSize;
            prevBlock.next = block.next;
            block.prev = prevBlock;
            block.size = undefined;
        }
    }
}

var fba: std.heap.FixedBufferAllocator = undefined;
const useMyAllocator = false;

pub fn alloc(_: *anyopaque, len: usize, _: mem.Alignment, _: usize) ?[*]u8 {
    return kmalloc(len);
}
pub fn free(_: *anyopaque, bufferToFree: []u8, _: mem.Alignment, _: usize) void {
    return kfree(bufferToFree.ptr);
}
pub fn allocator() mem.Allocator {
    if (useMyAllocator) {
        return .{
            .ptr = undefined,
            .vtable = &.{
                .alloc = alloc,
                .resize = mem.Allocator.noResize,
                .remap = mem.Allocator.noRemap,
                .free = free,
            },
        };
    } else {
        return fba.allocator();
    }
}

pub fn init() void {
    log.debug("++initializing kmalloc\n", .{});
    defer log.debug("--initialized kmalloc\n", .{});

    const initialSizeInPages: usize = 16;
    const initialSizeInBytes: usize = initialSizeInPages * memory.PAGE_SIZE;
    const page = vmm.allocatePages(initialSizeInPages) orelse {
        log.err("kmalloc.init:  failed to allocate page\n", .{});
        return;
    };
    const kmallocHeapSlice: []u8 = page[0..initialSizeInBytes];
    log.debug("kmalloc:  init: kmalloc heap at: 0x{X} until: 0x{X}\n", .{ @intFromPtr(page), @intFromPtr(page) + initialSizeInBytes });

    if (useMyAllocator) {
        if (kmallocHead == null) {
            kmallocHead = @alignCast(@ptrCast(page));

            kmallocHead.?.* = .{
                .size = initialSizeInBytes - blockHeaderSize,
                .isFree = true,
                .next = null,
                .prev = null,
            };
            kmallocSize = initialSizeInBytes;
        } else {
            log.err("kmalloc.init:  kmallocHead is not null\n", .{});
        }
        // kmallocTest();
        // debugPrint();
    } else {
        fba = std.heap.FixedBufferAllocator.init(kmallocHeapSlice);
    }

    log.info("kmalloc initilized yippe\n", .{});
}

fn kmallocTest() void {
    log.debug("++testing kmalloc\n", .{});
    defer log.debug("--tested kmalloc\n", .{});

    const useZigApi = true;
    if (!useZigApi) {
        const allocationSize: usize = 0x100;
        const buffer = kmalloc(allocationSize) orelse {
            log.err("kmallocTest:  failed to allocate memory\n", .{});
            return;
        };
        buffer[0] = 0x42;
        log.debug("kmallocTest:  allocated memory at: 0x{X} size: 0x{X}, content: {X}\n", .{
            @intFromPtr(buffer),
            allocationSize,
            buffer[0..allocationSize],
        });
        kfree(buffer);
    } else {
        const theAllocator = allocator();
        const allocationSize: usize = 0x100;
        const buffer = theAllocator.alloc(u8, allocationSize) catch |err| {
            log.err("kmallocTest.zigApi:  failed to allocate memory error: {}\n", .{err});
            return;
        };
        const buffer2 = theAllocator.alloc(u8, allocationSize) catch |err| {
            log.err("kmallocTest.zigApi:  failed to allocate memory error: {}\n", .{err});
            return;
        };
        buffer[0] = 0x42;
        log.debug("kmallocTest:  allocated memory at: 0x{X} size: 0x{X}, content: {X}\n", .{
            @intFromPtr(buffer.ptr),
            buffer.len,
            buffer,
        });
        theAllocator.free(buffer);
        theAllocator.free(buffer2);
    }
}

fn debugPrint() void {
    log.debug("++kmalloc debug print\n", .{});
    defer log.debug("--kmalloc debug printed\n", .{});

    var local = kmallocHead;
    while (local) |b| {
        log.debug("kmalloc.debugPrint:  block header: {}\nkmalloc.debugPrint:  block addr: 0x{X} size: 0x{X} isFree: {}, content: {X}\n", .{
            b,
            @intFromPtr(b) + blockHeaderSize,
            b.size,
            b.isFree,
            @as([*]u8, @ptrFromInt(@intFromPtr(b) + blockHeaderSize))[0..b.size],
        });
        local = b.next;
    }
}
