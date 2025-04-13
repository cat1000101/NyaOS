const vmm = @import("vmm.zig");
const debug = @import("../arch/x86/debug.zig");
const memory = @import("memory.zig");

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
            return @ptrFromInt(@intFromPtr(block) + blockHeaderSize);
        }
        current = block.next;
    }
    debug.printf("kmalloc:  no free block found, TODO: allocating new page\n", .{});
    return null;
}

pub fn kfree(ptr: [*]u8) void {
    const block: *blockHeader = @ptrFromInt(@intFromPtr(ptr) - blockHeaderSize);
    if (block.isFree) {
        debug.printf("kfree:  block is already free\n", .{});
        return;
    }
    block.isFree = true;
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

const mem = @import("std").mem;
pub fn alloc(_: *anyopaque, len: usize, _: mem.Alignment, _: usize) ?[*]u8 {
    return kmalloc(len);
}
pub fn free(_: *anyopaque, bufferToFree: []u8, _: mem.Alignment, _: usize) void {
    return kfree(bufferToFree.ptr);
}
pub fn allocator() mem.Allocator {
    return .{
        .ptr = kmallocHead.?,
        .vtable = &.{
            .alloc = alloc,
            .resize = mem.Allocator.noResize,
            .remap = mem.Allocator.noRemap,
            .free = free,
        },
    };
}

pub fn init() void {
    const page = vmm.allocatePage() orelse {
        debug.printf("kmalloc.init:  failed to allocate page\n", .{});
        return;
    };
    if (kmallocHead == null) {
        kmallocHead = @alignCast(@ptrCast(page));

        kmallocHead.?.* = .{
            .size = memory.PAGE_SIZE - blockHeaderSize,
            .isFree = true,
            .next = null,
            .prev = null,
        };
        kmallocSize = memory.PAGE_SIZE;
    } else {
        debug.printf("kmalloc.init:  kmallocHead is not null\n", .{});
    }

    // kmallocTest();
    // debugPrint();
}

fn kmallocTest() void {
    const useZigApi = true;
    if (!useZigApi) {
        const allocationSize: usize = 0x100;
        const buffer = kmalloc(allocationSize) orelse {
            debug.printf("kmallocTest:  failed to allocate memory\n", .{});
            return;
        };
        buffer[0] = 0x42;
        debug.printf("kmallocTest:  allocated memory at: 0x{X} size: 0x{X}, content: {X}\n", .{
            @intFromPtr(buffer),
            allocationSize,
            buffer[0..allocationSize],
        });
        kfree(buffer);
    } else {
        const theAllocator = allocator();
        const allocationSize: usize = 0x100;
        const buffer = theAllocator.alloc(u8, allocationSize) catch |err| {
            debug.printf("kmallocTest.zigApi:  failed to allocate memory error: {}\n", .{err});
            return;
        };
        buffer[0] = 0x42;
        debug.printf("kmallocTest:  allocated memory at: 0x{X} size: 0x{X}, content: {X}\n", .{
            @intFromPtr(buffer.ptr),
            buffer.len,
            buffer,
        });
        theAllocator.free(buffer);
    }
}

fn debugPrint() void {
    var local = kmallocHead;
    while (local) |b| {
        debug.printf("kmalloc.debugPrint:  block header: {}\nkmalloc.debugPrint:  block addr: 0x{X} size: 0x{X} isFree: {}, content: {X}\n", .{
            b,
            @intFromPtr(b) + blockHeaderSize,
            b.size,
            b.isFree,
            @as([*]u8, @ptrFromInt(@intFromPtr(b) + blockHeaderSize))[0..b.size],
        });
        local = b.next;
    }
}
