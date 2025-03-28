// brain storming: (i am leaveing this here for memories of the easier times)
// get the end of the kernel where there should be free memory that is not under 1MB
// also get the size of the free memory fro mthe bootloader/multiboot
// at the end i align and put the bitmap at the end of the kernel
// fill the bitmap for existing memory
const multiboot = @import("../multiboot.zig");
const virtio = @import("../arch/x86/virtio.zig");

const kernel_physical_start: *anyopaque = @extern(*anyopaque, .{ .name = "kernel_physical_start" });
const kernel_physical_end: *anyopaque = @extern(*anyopaque, .{ .name = "kernel_physical_end" });

const GIB = 1024 * 1024 * 1024;
const MIB = 1024 * 1024;
const KIB = 1024;
pub const physMemStart = 0x100000; // 1MB
pub const physPageSizes = 4096; // 4KB

pub const AllocatorError = error{
    OutOfMemory,
};

fn pageAlignAddress(addr: u32) u32 {
    return addr & ~(physPageSizes - 1);
}
fn pageAlignAddressDown(addr: u32) u32 {
    return pageAlignAddress(addr - physPageSizes);
}
fn pageAlignAddressUp(addr: u32) u32 {
    return pageAlignAddress(addr + physPageSizes);
}

pub fn BitMapAllocatorGeneric(comptime dynamicInitialStaticSize: usize) type {
    return struct {
        allocationSize: usize,
        size: usize = dynamicInitialStaticSize * 8,
        bitmap: [dynamicInitialStaticSize]u8,
        start: usize = 0,
        end: usize = 0,
        pub fn init(allocationSize: usize, start: usize, end: usize) @This() {
            return .{
                .allocationSize = allocationSize,
                .bitmap = [_]u8{0xFF} ** dynamicInitialStaticSize,
                .start = start,
                .end = end,
            };
        }
        fn allocate(this: *@This()) AllocatorError![*]u8 {
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
                return AllocatorError.OutOfMemory;
            } else {
                virtio.printf("allocator out of memory\n", .{});
                return AllocatorError.OutOfMemory;
            }
        }
        fn allocateMany(this: *@This(), count: usize) AllocatorError![*]u8 {
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
            } else {
                virtio.printf("allocator out of memory\n", .{});
                return AllocatorError.OutOfMemory;
            }
        }
        fn free(this: *@This(), buf: [*]u8) void {
            const index = @intFromPtr(buf) / this.allocationSize;
            virtio.printf("freeing memory at 0x{x} size: 0x{x}\n", .{ index * this.allocationSize, this.allocationSize });
            this.clear(index);
        }
        fn freeMany(this: *@This(), buf: [*]u8, count: usize) void {
            const bufAddress = @intFromPtr(buf);
            const slice: []u4096 = buf[0 .. count * this.allocationSize];
            _ = slice;
            virtio.printf("freeing memory at 0x{x} size: 0x{x}\n", .{ bufAddress, count * this.allocationSize });
            for (bufAddress / this.allocationSize..(bufAddress / this.allocationSize + count)) |i| {
                this.clear(i);
            }
        }
        fn resize(this: *@This(), newSize: usize) AllocatorError!void {
            _ = this;
            _ = newSize;
            // @panic("TODO: implement resize\n");
        }
        fn alignAddress(this: *@This(), addr: usize) usize {
            return addr & ~(this.allocationSize - 1);
        }
        fn alignDown(this: *@This(), addr: usize) usize {
            return this.alignAddress(addr - this.allocationSize);
        }
        fn alignUp(this: *@This(), addr: usize) usize {
            return this.alignAddress(addr + this.allocationSize);
        }
        fn isAligned(this: *@This(), addr: usize) bool {
            return (addr & (this.allocationSize - 1)) == 0;
        }
        fn set(this: *@This(), index: usize) void {
            const byteIndex = index / 8;
            const bitIndex: u3 = @intCast(index % 8);
            this.bitmap[byteIndex] |= @as(u8, 1) << bitIndex;
        }
        fn clear(this: *@This(), index: usize) void {
            const byteIndex = index / 8;
            const bitIndex: u3 = @intCast(index % 8);
            this.bitmap[byteIndex] &= ~(@as(u8, 1) << bitIndex);
        }
        fn check(this: *@This(), index: usize) bool {
            const byteIndex = index / 8;
            const bitIndex: u3 = @intCast(index % 8);
            return this.bitmap[byteIndex] & (@as(u8, 1) << bitIndex) != 0;
        }
    };
}

pub const BitMapAllocatorPageSize = BitMapAllocatorGeneric(physPageSizes);

pub var physBitMap = BitMapAllocatorPageSize.init(
    physPageSizes,
    physMemStart,
    physMemStart + (MIB * 3),
);

pub fn initPmm() void {
    setUsableMemory(&physBitMap);
    testPageAllocator(&physBitMap);
}

fn testPageAllocator(allocator: *BitMapAllocatorPageSize) void {
    const testAllocation = allocator.allocate() catch {
        virtio.printf("failed to allocate memory\n", .{});
        return;
    };
    allocator.free(testAllocation);
}

fn setUsableMemory(bitMap: *BitMapAllocatorPageSize) void {
    virtio.printf("setting usable memory for page allocator\n", .{});
    defer virtio.printf("finished usable memory setting? data: {}\n", .{bitMap});

    const header = multiboot.multibootInfo;
    const mmm: [*]multiboot.multiboot_mmap_entry = @ptrFromInt(header.mmap_addr);
    var endOfMemory: u32 = 0;
    for (mmm, 0..(header.mmap_length / @sizeOf(multiboot.multiboot_mmap_entry))) |entry, _| {
        if (entry.type == 1) {
            const start = bitMap.alignUp(@intCast(entry.addr));
            const end = bitMap.alignDown(@intCast(entry.addr + entry.len));
            endOfMemory = end;
            for ((start / physPageSizes)..(end / physPageSizes)) |index| {
                const address = index * physPageSizes;
                if (address <= physMemStart) {
                    continue;
                } else if ((index - bitMap.start / physPageSizes) >= bitMap.size) {
                    break;
                } else if (address >= @intFromPtr(kernel_physical_start) and address <= @intFromPtr(kernel_physical_end)) {
                    continue;
                }
                bitMap.clear(index - bitMap.start / physPageSizes);
            }
        }
    }
    if (endOfMemory < 8 * physPageSizes * physPageSizes) {
        virtio.printf("you dont have enough memory dummy\n", .{});
        // @panic("you dont have enough memory dummy\n");
    }
}
