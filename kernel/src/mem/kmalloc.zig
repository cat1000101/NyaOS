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
        debug.errorPrint("kmalloc:  size is 0\n", .{});
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
            debug.debugPrint("kmalloc:  allocated memory at: 0x{X} size: 0x{X}\n", .{
                @intFromPtr(block) + blockHeaderSize,
                alignedSize,
            });
            return @ptrFromInt(@intFromPtr(block) + blockHeaderSize);
        }
        current = block.next;
    }
    debug.errorPrint("kmalloc:  no free block found, TODO: allocating new page\n", .{});
    return null;
}

pub fn kfree(ptr: [*]u8) void {
    const block: *blockHeader = @ptrFromInt(@intFromPtr(ptr) - blockHeaderSize);
    if (block.isFree) {
        debug.errorPrint("kfree:  block is already free\n", .{});
        return;
    }
    block.isFree = true;
    debug.debugPrint("kfree:  freed memory at: 0x{X} size: 0x{X}\n", .{
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
    debug.debugPrint("++initializing kmalloc\n", .{});
    defer debug.debugPrint("--initialized kmalloc\n", .{});

    const initialSizeInPages: usize = 16;
    const initialSizeInBytes: usize = initialSizeInPages * memory.PAGE_SIZE;
    const page = vmm.allocatePages(initialSizeInPages) orelse {
        debug.errorPrint("kmalloc.init:  failed to allocate page\n", .{});
        return;
    };
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
        debug.errorPrint("kmalloc.init:  kmallocHead is not null\n", .{});
    }

    // kmallocTest();
    // debugPrint();
    debug.infoPrint("kmalloc initilized yippe\n", .{});
}

fn kmallocTest() void {
    debug.debugPrint("++testing kmalloc\n", .{});
    defer debug.debugPrint("--tested kmalloc\n", .{});

    const useZigApi = true;
    if (!useZigApi) {
        const allocationSize: usize = 0x100;
        const buffer = kmalloc(allocationSize) orelse {
            debug.errorPrint("kmallocTest:  failed to allocate memory\n", .{});
            return;
        };
        buffer[0] = 0x42;
        debug.debugPrint("kmallocTest:  allocated memory at: 0x{X} size: 0x{X}, content: {X}\n", .{
            @intFromPtr(buffer),
            allocationSize,
            buffer[0..allocationSize],
        });
        kfree(buffer);
    } else {
        const theAllocator = allocator();
        const allocationSize: usize = 0x100;
        const buffer = theAllocator.alloc(u8, allocationSize) catch |err| {
            debug.errorPrint("kmallocTest.zigApi:  failed to allocate memory error: {}\n", .{err});
            return;
        };
        const buffer2 = theAllocator.alloc(u8, allocationSize) catch |err| {
            debug.errorPrint("kmallocTest.zigApi:  failed to allocate memory error: {}\n", .{err});
            return;
        };
        buffer[0] = 0x42;
        debug.debugPrint("kmallocTest:  allocated memory at: 0x{X} size: 0x{X}, content: {X}\n", .{
            @intFromPtr(buffer.ptr),
            buffer.len,
            buffer,
        });
        theAllocator.free(buffer);
        theAllocator.free(buffer2);
    }
}

fn debugPrint() void {
    debug.debugPrint("++kmalloc debug print\n", .{});
    defer debug.debugPrint("--kmalloc debug printed\n", .{});

    var local = kmallocHead;
    while (local) |b| {
        debug.debugPrint("kmalloc.debugPrint:  block header: {}\nkmalloc.debugPrint:  block addr: 0x{X} size: 0x{X} isFree: {}, content: {X}\n", .{
            b,
            @intFromPtr(b) + blockHeaderSize,
            b.size,
            b.isFree,
            @as([*]u8, @ptrFromInt(@intFromPtr(b) + blockHeaderSize))[0..b.size],
        });
        local = b.next;
    }
}
