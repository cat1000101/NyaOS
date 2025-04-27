const std = @import("std");
const mem = @import("std").mem;
const debug = @import("../arch/x86/debug.zig");
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

pub const BitMapAllocatorGeneric = struct {
    bitmap: []u8,
    size: usize = 0,
    allocationSize: usize,
    /// inclusive
    start: usize = 0,
    /// exclusive
    end: usize = 0,
    pub fn init(bitmap: []u8, allocationSize: usize, start: usize, end: usize, full: bool) @This() {
        const byte: u8 = if (full) 0xff else 0x00;
        const lstart = alignAddressUp(start, allocationSize);
        const lend = alignAddressDown(end, allocationSize);
        for (bitmap) |*byteView| {
            byteView.* = byte;
        }
        var retAllocator: @This() = .{
            .bitmap = bitmap,
            .size = bitmap.len * 8,
            .allocationSize = allocationSize,
            .start = lstart,
            .end = lend,
        };
        retAllocator.setUsableMemory(multiboot.multibootInfo);
        // retAllocator.debugPrint();
        return retAllocator;
    }

    pub fn alloc(this: *@This(), amount: usize) AllocatorError![*]u8 {
        if (this.find(amount)) |address| {
            const start: usize = (@intFromPtr(address) - this.start) / this.allocationSize;
            for (start..(start + amount)) |i| {
                this.set(i);
            }
            debug.debugPrint("memory.alloc:  allocated memory at 0x{X} size: 0x{X}\n", .{ @intFromPtr(address), amount * this.allocationSize });
            return address;
        } else {
            debug.errorPrint("memory.alloc:  TODO: make resize/realloc of the allocator or allocator buffer or whatever\n", .{});
            return AllocatorError.OutOfMemory;
        }
    }

    fn find(this: *@This(), amount: usize) ?[*]u8 {
        var start: usize = 0;
        var found: usize = 0;
        for (0..this.size) |index| {
            if (this.check(index) == false) {
                if (found == 0) {
                    start = index;
                }
                found += 1;
                const address: usize = (start * this.allocationSize) + this.start;
                if (found == amount and address < this.end) {
                    debug.debugPrint("memory.find:  allocator found not used memory at 0x{X} size: 0x{X}\n", .{ address, amount * this.allocationSize });
                    return @ptrFromInt(address);
                }
            } else {
                found = 0;
                start = 0;
            }
        }
        debug.errorPrint("memory.find:  allocator not found memory\n", .{});
        return null;
    }

    pub fn resize(this: *@This(), memory: []u8, new_amount: usize) bool {
        const indexAllocated: usize = (@intFromPtr(memory.ptr) / this.allocationSize) - (this.start / this.allocationSize);
        const oldCount: usize = memory.len / this.allocationSize;
        const count: usize = new_amount;

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

    pub fn remap(this: *@This(), memory: []u8, new_amount: usize) ?[*]u8 {
        if (this.resize(memory, new_amount)) {
            return memory.ptr;
        }

        if (this.find(new_amount)) |address| {
            const start: usize = (@intFromPtr(address) - this.start) / this.allocationSize;
            const count: usize = new_amount;
            if (start + count > this.size) {
                debug.errorPrint("memory.remap:  got length not in range\n", .{});
                return null;
            }
            for (start..(start + count)) |i| {
                this.set(i);
            }
            for ((@intFromPtr(memory.ptr) / this.allocationSize) - (this.start / this.allocationSize)..(@intFromPtr(memory.ptr) / this.allocationSize) - this.start / this.allocationSize + memory.len / this.allocationSize) |i| {
                this.clear(i);
            }
            debug.debugPrint("memory.remap:  allocated memory at 0x{X} size: 0x{X}\n", .{ @intFromPtr(address), count * this.allocationSize });
            debug.debugPrint("memory.remap:  freed memory at 0x{X} size: 0x{X}\n", .{ @intFromPtr(memory.ptr), memory.len });
            return address;
        } else {
            return null;
        }
    }

    pub fn free(this: *@This(), address: [*]u8, size: usize) void {
        if (size == 0) {
            debug.errorPrint("memory.free:  got 0 length\n", .{});
            return;
        }
        if (!this.isAligned(@intFromPtr(address))) {
            debug.errorPrint("memory.free:  got address not alighned\n", .{});
            return;
        }

        debug.debugPrint("memory.free:  freeing memory at 0x{X} size: 0x{X}\n", .{ @intFromPtr(address), size });
        const index = (@intFromPtr(address) / this.allocationSize) - (this.start / this.allocationSize);
        for (index..(index + size)) |i| {
            this.clear(i);
        }
    }

    pub fn reallocAllocatorBuffer(this: *@This(), newBuffer: []u8) bool {
        if (newBuffer.len * 8 * this.allocationSize + this.start > this.end) {
            return false;
        }
        for (this.bitmap, newBuffer) |byte, *byteView| {
            byteView.* = byte;
        }
        if (this.bitmap.len < newBuffer.len) {
            for (this.bitmap.len..newBuffer.len) |i| {
                this.bitmap[i] = 0x00;
            }
        }
        this.bitmap = newBuffer;
        this.size = newBuffer.len * 8;

        this.setUsableMemory(multiboot.multibootInfo);

        return true;
    }

    pub fn isAligned(this: *@This(), addr: usize) bool {
        return (addr & (this.allocationSize - 1)) == 0;
    }
    pub fn set(this: *@This(), index: usize) void {
        const byteIndex = index / 8;
        const bitIndex: u3 = @intCast(index % 8);
        this.bitmap[byteIndex] |= (@as(u8, 1) << bitIndex);
    }
    pub fn clear(this: *@This(), index: usize) void {
        const byteIndex = index / 8;
        const bitIndex: u3 = @intCast(index % 8);
        this.bitmap[byteIndex] &= ~(@as(u8, 1) << bitIndex);
    }
    pub fn check(this: *@This(), index: usize) bool {
        const byteIndex = index / 8;
        const bitIndex: u3 = @intCast(index % 8);
        return (this.bitmap[byteIndex] & (@as(u8, 1) << bitIndex)) != 0;
    }
    pub fn setUsableMemory(this: *@This(), mbh: *multiboot.multiboot_info) void {
        debug.debugPrint("++setting usable memory for page allocator\n", .{});
        defer debug.debugPrint("--finished usable memory setting?\n", .{});

        const header = mbh;
        const mmm: [*]multiboot.multiboot_mmap_entry = @ptrFromInt(header.mmap_addr);
        const startIndex = this.start / this.allocationSize;
        const endIndex = this.end / this.allocationSize;
        for (mmm, 0..(header.mmap_length / @sizeOf(multiboot.multiboot_mmap_entry))) |entry, _| {
            const start = alignAddressUp(@intCast(entry.addr), this.allocationSize);
            var end: u32 = 0;
            if (entry.addr + entry.len > 0xFFFFFFFF) {
                end = 0xFFFFFFFF - this.allocationSize;
            } else {
                end = alignAddressDown(@intCast(entry.addr + entry.len), this.allocationSize);
            }
            var entryStartIndex = start / this.allocationSize;
            var entryEndIndex = end / this.allocationSize;

            debug.debugPrint("memory.setUsableMemory:  entry: {any}\n", .{entry});
            debug.debugPrint("memory.setUsableMemory:  entry start index: {} entry end index: {} start,end {},{}\n", .{
                entryStartIndex,
                entryEndIndex,
                start,
                end,
            });

            if (entryEndIndex < startIndex) {
                debug.debugPrint("memory.setUsableMemory:  entry not in range(before)\n", .{});
                continue;
            } else if (entryStartIndex > endIndex) {
                debug.debugPrint("memory.setUsableMemory:  entry not in range(after)\n", .{});
                break;
            } else if (entryStartIndex > this.size + startIndex) {
                debug.debugPrint("memory.setUsableMemory:  entry start index out of range\n", .{});
                break;
            }
            if (startIndex > entryStartIndex) {
                entryStartIndex = startIndex;
            }
            if (endIndex < entryEndIndex) {
                entryEndIndex = endIndex;
            }

            for (entryStartIndex..entryEndIndex) |index| {
                if (entry.type != 1) {
                    this.set(index - startIndex);
                    continue;
                } else if (index >= this.size) {
                    debug.debugPrint("memory.setUsableMemory:  entry index out of range\n", .{});
                    break;
                }
                const address = index * this.allocationSize;
                if (address <= physMemStart or (address >= @intFromPtr(kernel_physical_start) and address <= @intFromPtr(kernel_physical_end)) or (address >= @intFromPtr(kernel_start) and address <= @intFromPtr(kernel_end))) {
                    this.set(index - startIndex);
                    continue;
                }
                this.clear(index - startIndex);
            }
        }
    }
    pub fn debugPrint(this: *@This()) void {
        debug.infoPrint("++memory bitmap debug print\n", .{});
        defer debug.infoPrint("--memory bitmap debug printed\n", .{});

        debug.infoPrint("memory.debugPrint:  size: {}\n", .{this.size});
        debug.infoPrint("", .{});
        for (0..this.size) |index| {
            const address: usize = (index * this.allocationSize) + this.start;
            if (address < this.end) {
                if (this.check(index) == true) {
                    debug.printf("10x{X} ", .{address});
                } else {
                    debug.printf("00x{X} ", .{address});
                }
            }
        }
        debug.printf("\n", .{});
    }
};

pub fn alignAddress(addr: u32, alignment: usize) u32 {
    return addr & ~(alignment - 1);
}
pub fn alignAddressDown(addr: u32, alignment: usize) u32 {
    return alignAddress(addr - physPageSizes, alignment);
}
pub fn alignAddressUp(addr: u32, alignment: usize) u32 {
    return alignAddress(addr + physPageSizes - 1, alignment);
}
