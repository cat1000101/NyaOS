const virtio = @import("../arch/x86/virtio.zig");

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

pub fn BitMapAllocatorGeneric(comptime dynamicInitialStaticSize: usize) type {
    return struct {
        bitmap: [dynamicInitialStaticSize]u8,
        size: usize = dynamicInitialStaticSize * 8,
        allocationSize: usize,
        /// inclusive
        start: usize = 0,
        /// exclusive
        end: usize = 0,
        pub fn init(allocationSize: usize, start: usize, end: usize) @This() {
            return .{
                .allocationSize = allocationSize,
                .bitmap = [_]u8{0xFF} ** dynamicInitialStaticSize,
                .start = start,
                .end = end,
            };
        }
        pub fn allocate(this: *@This()) AllocatorError![*]u8 {
            for (0..this.size) |index| {
                const address: usize = (index * this.allocationSize) + this.start;
                if (this.check(index) == false and address >= this.start and address < this.end) {
                    this.set(index);
                    virtio.printf("allocated memory at 0x{x} size: 0x{x}\n", .{ address, this.allocationSize });
                    return @ptrFromInt(address);
                }
            }
            if (this.end > (this.size * this.allocationSize) + this.start) {
                virtio.printf("TODO: need to realocate the bitmap to make it bigger, needed size: 0x{x}\n", .{
                    (this.end - this.start) / (this.allocationSize * 8),
                });
                return AllocatorError.AllocatorResizeError;
            } else {
                virtio.printf("allocator out of memory\n", .{});
                return AllocatorError.OutOfMemory;
            }
        }
        pub fn allocateMany(this: *@This(), count: usize) AllocatorError![*]u8 {
            var start: usize = 0;
            var found: usize = 0;
            for (0..this.size) |index| {
                if (this.check(index) == false) {
                    if (found == 0) {
                        start = index;
                    }
                    found += 1;
                    const address: usize = (start * this.allocationSize) + this.start;
                    if (found == count and address >= this.start and address < this.end) {
                        for (start..(start + count)) |i| {
                            this.set(i);
                        }
                        virtio.printf("allocated memory at 0x{x} size: 0x{x}\n", .{ address, count * this.allocationSize });
                        return @ptrFromInt(address);
                    }
                } else {
                    found = 0;
                }
            }
            if (this.end > (this.size * this.allocationSize) + this.start) {
                virtio.printf("TODO: need to realocate the bitmap to make it bigger, needed size: 0x{x}\n", .{
                    (this.end - this.start) / (this.allocationSize * 8),
                });
                return AllocatorError.AllocatorResizeError;
            } else {
                virtio.printf("allocator out of memory\n", .{});
                return AllocatorError.OutOfMemory;
            }
        }
        pub fn free(this: *@This(), buf: [*]u8) void {
            const index = @intFromPtr(buf) / this.allocationSize;
            virtio.printf("freeing memory at 0x{x} size: 0x{x}\n", .{ index * this.allocationSize, this.allocationSize });
            this.clear(index);
        }
        pub fn freeMany(this: *@This(), buf: [*]u8, count: usize) void {
            const bufAddress = @intFromPtr(buf);
            const slice: []u4096 = buf[0 .. count * this.allocationSize];
            _ = slice;
            virtio.printf("freeing memory at 0x{x} size: 0x{x}\n", .{ bufAddress, count * this.allocationSize });
            for (bufAddress / this.allocationSize..(bufAddress / this.allocationSize + count)) |i| {
                this.clear(i);
            }
        }
        pub fn resize(this: *@This(), newSize: usize) AllocatorError!void {
            _ = this;
            _ = newSize;
            // @panic("TODO: implement resize\n");
        }
        pub fn alignAddress(this: *@This(), addr: usize) usize {
            return addr & ~(this.allocationSize - 1);
        }
        pub fn alignDown(this: *@This(), addr: usize) usize {
            return this.alignAddress(addr - this.allocationSize);
        }
        pub fn alignUp(this: *@This(), addr: usize) usize {
            return this.alignAddress(addr + this.allocationSize);
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
            return this.bitmap[byteIndex] & (@as(u8, 1) << bitIndex) != 0;
        }
    };
}
