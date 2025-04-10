const std = @import("std");
const mem = @import("std").mem;
const virtio = @import("../arch/x86/virtio.zig");
const multiboot = @import("../multiboot.zig");

pub const kernel_physical_start: *anyopaque = @extern(*anyopaque, .{ .name = "kernel_physical_start" });
pub const kernel_physical_end: *anyopaque = @extern(*anyopaque, .{ .name = "kernel_physical_end" });
pub const kernel_start: *anyopaque = @extern(*anyopaque, .{ .name = "kernel_start" });
pub const kernel_end: *anyopaque = @extern(*anyopaque, .{ .name = "kernel_end" });
pub const kernel_size_in_4MIB_pages: *anyopaque = @extern(*anyopaque, .{ .name = "kernel_size_in_4MIB_pages" });
pub const kernel_size_in_4KIB_pages: *anyopaque = @extern(*anyopaque, .{ .name = "kernel_size_in_4KIB_pages" });

pub const GIB = 1024 * 1024 * 1024;
pub const MIB = 1024 * 1024;
pub const KIB = 1024;

pub const PAGE_SIZE: u32 = 4 * KIB;
pub const DIR_SIZE: u32 = 4 * MIB;

pub const KERNEL_ADDRESS_SPACE: u32 = 0xC0000000; // 3GB
pub const physMemStart = 0x100000; // 1MB
pub const physPageSizes = 4096; // 4KB

pub const AllocatorError = error{
    OutOfMemory,
    AllocatorResizeError,
};

// allocator api docs are bad and people explanations are bad
// ok so to summury:
// alloc: tries to find memory in the allocator buffer(or whatever system) else try to expand the allocator else return null
// resize: tries to grow or shrink memory "possesion" without expanding the allocator/get more memory
// remap: resize or try to alloc without the expand allocator/get more memory
// free: free the memory from the allocator

pub fn BitMapAllocatorGeneric(comptime dynamicInitialStaticSize: usize) type {
    return struct {
        bitmap: [dynamicInitialStaticSize]u8,
        size: usize = dynamicInitialStaticSize * 8,
        allocationSize: usize,
        /// inclusive
        start: usize = 0,
        /// exclusive
        end: usize = 0,
        pub fn init(allocationSize: usize, start: usize, end: usize, full: bool) @This() {
            const byte: u8 = if (full) 0xff else 0x00;
            const lstart = alignAddressUp(start - 1, allocationSize);
            const lend = alignAddressDown(end, allocationSize);
            return .{
                .allocationSize = allocationSize,
                .bitmap = [_]u8{byte} ** dynamicInitialStaticSize,
                .start = lstart,
                .end = lend,
            };
        }

        pub fn allocator(self: *@This()) mem.Allocator {
            return .{
                .ptr = self,
                .vtable = &.{
                    .alloc = alloc,
                    .resize = resize,
                    .remap = remap,
                    .free = free,
                },
            };
        }

        pub fn alloc(ctx: *anyopaque, len: usize, alignment: mem.Alignment, ret_addr: usize) ?[*]u8 {
            const this: *@This() = @ptrCast(@alignCast(ctx));
            if (len == 0) {
                virtio.printf("bitmap: alloc:  got 0 length\n", .{});
                return null;
            } else if (!this.isAligned(len)) {
                virtio.printf("bitmap: alloc:  got length not alighned\n", .{});
                return null;
            }

            if (find(ctx, len, alignment, ret_addr)) |address| {
                const start: usize = (@intFromPtr(address) - this.start) / this.allocationSize;
                const count: usize = len / this.allocationSize;
                if (start + count > this.size) {
                    virtio.printf("bitmap: alloc:  got length not in range\n", .{});
                    return null;
                }
                for (start..(start + count)) |i| {
                    this.set(i);
                }
                virtio.printf("allocated memory at 0x{X} size: 0x{X}\n", .{ @intFromPtr(address), count * this.allocationSize });
                return address;
            } else {
                virtio.printf("TODO: make resize/realloc of the allocator or allocator buffer or whatever\n", .{});
                return null;
            }
        }

        fn find(ctx: *anyopaque, len: usize, alignment: mem.Alignment, ret_addr: usize) ?[*]u8 {
            const this: *@This() = @ptrCast(@alignCast(ctx));
            _ = ret_addr;
            _ = alignment;
            if (len == 0) {
                virtio.printf("bitmap: find:  got 0 length\n", .{});
                return null;
            } else if (!this.isAligned(len)) {
                virtio.printf("bitmap: find:  got length not alighned\n", .{});
                return null;
            }

            const count: usize = len / this.allocationSize;
            var start: usize = 0;
            var found: usize = 0;
            for (0..this.size) |index| {
                if (this.check(index) == false) {
                    if (found == 0) {
                        start = index;
                    }
                    found += 1;
                    const address: usize = (start * this.allocationSize) + this.start;
                    if (found == count and address < this.end) {
                        virtio.printf("allocator found not used memory at 0x{X} size: 0x{X}\n", .{ address, count * this.allocationSize });
                        return @ptrFromInt(address);
                    }
                } else {
                    found = 0;
                    start = 0;
                }
            }
            return null;
        }

        pub fn resize(ctx: *anyopaque, memory: []u8, alignment: mem.Alignment, new_len: usize, ret_addr: usize) bool {
            _ = ret_addr;
            _ = alignment;
            const this: *@This() = @ptrCast(@alignCast(ctx));
            if (new_len == 0 or memory.len == 0) {
                virtio.printf("bitmap: resize:  got 0 length\n", .{});
                return false;
            } else if (!this.isAligned(new_len) or !this.isAligned(memory.len)) {
                virtio.printf("bitmap: resize:  got length not alighned\n", .{});
                return false;
            } else if (!this.isAligned(@intFromPtr(memory.ptr))) {
                virtio.printf("bitmap: resize:  got address not alighned\n", .{});
                return false;
            }

            const indexAllocated: usize = (@intFromPtr(memory.ptr) / this.allocationSize) - (this.start / this.allocationSize);
            const oldCount: usize = memory.len / this.allocationSize;
            const count: usize = new_len / this.allocationSize;

            if (count == oldCount) {
                return true;
            } else if (count < oldCount) {
                for ((indexAllocated + count)..(indexAllocated + oldCount)) |index| {
                    this.clear(index);
                }
                return true;
            }

            if (indexAllocated + count > this.size) {
                return false;
            }

            const resizeAtPlacePossible = for ((indexAllocated + oldCount)..(indexAllocated + count)) |i| {
                if (this.check(i) == true) {
                    break false;
                }
            } else true;
            if (resizeAtPlacePossible) {
                for ((indexAllocated + oldCount)..(indexAllocated + count)) |i| {
                    this.set(i);
                }
                return true;
            } else {
                return false;
            }
        }

        pub fn remap(ctx: *anyopaque, memory: []u8, alignment: mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
            const this: *@This() = @ptrCast(@alignCast(ctx));
            if (new_len == 0 or memory.len == 0) {
                virtio.printf("bitmap: remap:  got 0 length\n", .{});
                return null;
            } else if (!this.isAligned(new_len) or !this.isAligned(memory.len)) {
                virtio.printf("bitmap: remap:  got length not alighned\n", .{});
                return null;
            } else if (!this.isAligned(@intFromPtr(memory.ptr))) {
                virtio.printf("bitmap: remap:  got address not alighned\n", .{});
                return null;
            }

            if (resize(ctx, memory, alignment, new_len, ret_addr)) {
                return memory.ptr;
            }

            if (find(ctx, new_len, alignment, ret_addr)) |address| {
                const start: usize = (@intFromPtr(address) - this.start) / this.allocationSize;
                const count: usize = new_len / this.allocationSize;
                if (start + count > this.size) {
                    virtio.printf("bitmap: remap:  got length not in range\n", .{});
                    return null;
                }
                for (start..(start + count)) |i| {
                    this.set(i);
                }
                for ((@intFromPtr(memory.ptr) / this.allocationSize) - (this.start / this.allocationSize)..(@intFromPtr(memory.ptr) / this.allocationSize) - this.start / this.allocationSize + memory.len / this.allocationSize) |i| {
                    this.clear(i);
                }
                virtio.printf("allocated memory at 0x{X} size: 0x{X}\n", .{ @intFromPtr(address), count * this.allocationSize });
                virtio.printf("freed memory at 0x{X} size: 0x{X}\n", .{ @intFromPtr(memory.ptr), memory.len });
                return address;
            } else {
                return null;
            }
        }

        pub fn free(ctx: *anyopaque, memory: []u8, alignment: mem.Alignment, ret_addr: usize) void {
            const this: *@This() = @ptrCast(@alignCast(ctx));
            _ = ret_addr;
            _ = alignment;
            if (memory.len == 0) {
                virtio.printf("bitmap: free:  got 0 length\n", .{});
                return;
            }
            if (!this.isAligned(memory.len)) {
                virtio.printf("bitmap: free:  got length not alighned\n", .{});
                return;
            }
            if (!this.isAligned(@intFromPtr(memory.ptr))) {
                virtio.printf("bitmap: free:  got address not alighned\n", .{});
                return;
            }
            virtio.printf("freeing memory at 0x{X} size: 0x{X}\n", .{ @intFromPtr(memory.ptr), memory.len });
            const index = (@intFromPtr(memory.ptr) / this.allocationSize) - (this.start / this.allocationSize);
            for (index..(index + memory.len / this.allocationSize)) |i| {
                this.clear(i);
            }
        }

        pub fn isAligned(this: *@This(), addr: usize) bool {
            return (addr & (this.allocationSize - 1)) == 0;
        }
        pub fn set(this: *@This(), index: usize) void {
            const byteIndex = index / 8;
            const bitIndex: u3 = @intCast(index % 8);
            this.bitmap[byteIndex] |= @as(u8, 1) << bitIndex;
        }
        pub fn clear(this: *@This(), index: usize) void {
            const byteIndex = index / 8;
            const bitIndex: u3 = @intCast(index % 8);
            this.bitmap[byteIndex] &= ~(@as(u8, 1) << bitIndex);
        }
        pub fn check(this: *@This(), index: usize) bool {
            const byteIndex = index / 8;
            const bitIndex: u3 = @intCast(index % 8);
            return this.bitmap[byteIndex] & (@as(u8, 1) << bitIndex) == 1;
        }
        pub fn setUsableMemory(bitMap: *@This(), mbh: *multiboot.multiboot_info) void {
            // virtio.printf("setting usable memory for page allocator\n", .{});
            // defer virtio.printf("finished usable memory setting?\n", .{}); // data: {}\n", .{bitMap});

            const header = mbh;
            const mmm: [*]multiboot.multiboot_mmap_entry = @ptrFromInt(header.mmap_addr);
            var endOfMemory: u32 = 0;
            for (mmm, 0..(header.mmap_length / @sizeOf(multiboot.multiboot_mmap_entry))) |entry, _| {
                if (entry.type == 1) {
                    const start = alignAddressUp(@intCast(entry.addr), bitMap.allocationSize);
                    const end = alignAddressDown(@intCast(entry.addr + entry.len), bitMap.allocationSize);
                    endOfMemory = end;
                    for ((start / physPageSizes)..(end / physPageSizes)) |index| {
                        const startIndex = bitMap.start / physPageSizes;
                        const endIndex = bitMap.end / physPageSizes;
                        if (index < startIndex or index >= endIndex) {
                            continue;
                        }
                        const address = index * physPageSizes;
                        if (address <= physMemStart or (address >= @intFromPtr(kernel_physical_start) and address <= @intFromPtr(kernel_physical_end))) {
                            bitMap.set(index - startIndex);
                        } else if ((index - startIndex) >= bitMap.size) {
                            break;
                        }
                        bitMap.clear(index - startIndex);
                    }
                }
            }
            if (endOfMemory < 8 * physPageSizes * physPageSizes) {
                virtio.printf("you dont have enough memory dummy\n", .{});
                // @panic("you dont have enough memory dummy\n");
            }
        }
        pub fn debugPrint(this: *@This()) void {
            for (0..this.size) |index| {
                const address: usize = (index * this.allocationSize) + this.start;
                if (address >= this.start and address < this.end) {
                    if (this.check(index) == false) {
                        virtio.printf("00x{X} ", .{address});
                    } else {
                        virtio.printf("10x{X} ", .{address});
                    }
                }
            }
            virtio.printf("\n", .{});
        }
    };
}

pub fn alignAddress(addr: u32, alignment: usize) u32 {
    return addr & ~(alignment - 1);
}
pub fn alignAddressDown(addr: u32, alignment: usize) u32 {
    return alignAddress(addr - physPageSizes, alignment);
}
pub fn alignAddressUp(addr: u32, alignment: usize) u32 {
    return alignAddress(addr + physPageSizes, alignment);
}
