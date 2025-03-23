// brain storming: (i am leaveing this here for memories of the easier times)
// get the end of the kernel where there should be free memory that is not under 1MB
// also get the size of the free memory fro mthe bootloader/multiboot
// at the end i align and put the bitmap at the end of the kernel
// fill the bitmap for existing memory
const multiboot = @import("../multiboot.zig");
const virtio = @import("../arch/x86/virtio.zig");

extern const kernel_start: u32;
extern const kernel_end: u32;

pub const physMemStart = 0x100000; // 1MB
pub const physPageSizes = 4096; // 4KB

pub const AllocatorError = error{
    OutOfMemory,
};

pub fn pageAlignUp(addr: u32) u32 {
    return (addr + physPageSizes - 1) & ~(physPageSizes - 1);
}

pub fn pageAlignDown(addr: u32) u32 {
    return addr & ~(physPageSizes - 1);
}

pub fn BitMapAllocatorGeneric(comptime dynamicSize: u32) type {
    return struct {
        size: u32 = dynamicSize * 8,
        allocationSize: u32,
        bitmap: [dynamicSize]u8,
        endOfMemory: u32 = 0,
        pub fn initFull(allocationSize: u32) @This() {
            return .{
                .allocationSize = allocationSize,
                .bitmap = [_]u8{0xFF} ** dynamicSize,
            };
        }
        pub fn initEmpty(allocationSize: u32) @This() {
            return .{
                .allocationSize = allocationSize,
                .bitmap = [_]u8{0x00} ** dynamicSize,
            };
        }
        pub fn allocate(this: *@This()) AllocatorError!*u32 {
            for (0..this.size) |index| {
                if (this.check(index) == false) {
                    this.set(index);
                    virtio.printf("allocated memory at 0x{x} size: 0x{x}\n", .{ index * this.allocationSize, this.allocationSize });
                    return @ptrFromInt(index * this.allocationSize);
                }
            }
            return AllocatorError.OutOfMemory;
        }
        pub fn allocateMany(this: *@This(), count: u32) AllocatorError!*u32 {
            var start: u32 = 0;
            var found: u32 = 0;
            for (0..this.size) |index| {
                if (this.check(index) == false) {
                    if (found == 0) {
                        start = index;
                    }
                    found += 1;
                    if (found == count) {
                        for (start..(start + count)) |i| {
                            this.set(i);
                        }
                        virtio.printf("allocated memory at 0x{x} size: 0x{x}\n", .{ start * this.allocationSize, count * this.allocationSize });
                        return @ptrFromInt(start * this.allocationSize);
                    }
                } else {
                    found = 0;
                }
            }
            return AllocatorError.OutOfMemory;
        }
        pub fn free(this: *@This(), addr: u32) void {
            const index = addr / this.allocationSize;
            virtio.printf("freeing memory at 0x{x} size: 0x{x}\n", .{ index * this.allocationSize, this.allocationSize });
            this.clear(index);
        }
        pub fn freeMany(this: *@This(), addr: u32, count: u32) void {
            virtio.printf("freeing memory at 0x{x} size: 0x{x}\n", .{ addr, count * this.allocationSize });
            for (addr / this.allocationSize..(addr / this.allocationSize + count)) |i| {
                this.clear(i);
            }
        }
        pub fn resize(this: *@This(), newSize: u32) AllocatorError!void {
            _ = this;
            _ = newSize;
            // @panic("TODO: implement resize\n");
        }
        pub fn alignAddress(this: *@This(), addr: u32) u32 {
            return addr & ~(this.allocationSize - 1);
        }
        pub fn alignDown(this: *@This(), addr: u32) u32 {
            return this.alignAddress(addr - this.allocationSize);
        }
        pub fn alignUp(this: *@This(), addr: u32) u32 {
            return this.alignAddress(addr + this.allocationSize);
        }
        fn set(this: *@This(), index: u32) void {
            const byteIndex = index / 8;
            const bitIndex: u3 = @intCast(index % 8);
            this.bitmap[byteIndex] |= @as(u8, 1) << bitIndex;
        }
        fn clear(this: *@This(), index: u32) void {
            const byteIndex = index / 8;
            const bitIndex: u3 = @intCast(index % 8);
            this.bitmap[byteIndex] &= ~(@as(u8, 1) << bitIndex);
        }
        fn check(this: *@This(), index: u32) bool {
            const byteIndex = index / 8;
            const bitIndex: u3 = @intCast(index % 8);
            return this.bitmap[byteIndex] & (@as(u8, 1) << bitIndex) != 0;
        }
    };
}

pub const BitMapAllocatorPageSize = BitMapAllocatorGeneric(physPageSizes);

pub var physBitMap = BitMapAllocatorPageSize.initFull(physPageSizes);

pub fn initPmm() void {
    setUsableMemory(&physBitMap);
    const testAllocation = physBitMap.allocate() catch {
        virtio.printf("failed to allocate memory\n", .{});
        return;
    };
    physBitMap.free(@intFromPtr(testAllocation));
}

fn setUsableMemory(bitMap: *BitMapAllocatorPageSize) void {
    const header = multiboot.multibootInfo;
    const mmm: [*]multiboot.multiboot_mmap_entry = @ptrFromInt(header.mmap_addr);
    var endOfMemory: u32 = 0;
    for (mmm, 0..(header.mmap_length / @sizeOf(multiboot.multiboot_mmap_entry))) |entry, _| {
        if (entry.type == 1) {
            const start = bitMap.alignUp(@intCast(entry.addr));
            const end = bitMap.alignDown(@intCast(entry.addr + entry.len));
            endOfMemory = end;
            for ((start / physPageSizes)..(end / physPageSizes)) |index| {
                if ((index * physPageSizes) <= physMemStart) {
                    continue;
                } else if (entry.len < physMemStart * 2) {
                    break;
                } else if (index >= bitMap.size) {
                    break;
                } else if ((index * physPageSizes) >= @intFromPtr(&kernel_start) and (index * physPageSizes) <= @intFromPtr(&kernel_end)) {
                    continue;
                }
                bitMap.clear(index);
            }
        }
    }
    bitMap.endOfMemory = endOfMemory;
    // if (endOfMemory < 8 * physPageSizes * physPageSizes) {
    //     @panic("you dont have enough memory dummy\n");
    // }
    virtio.printf("finished usable memory setting?\n", .{}); //.{bitMap});
}
