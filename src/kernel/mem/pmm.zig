// brain storming:
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
        pub fn set(this: *@This(), index: u32) void {
            const byteIndex = index / 8;
            const bitIndex: u3 = @intCast(index % 8);
            this.bitmap[byteIndex] |= @as(u8, 1) << bitIndex;
        }
        pub fn clear(this: *@This(), index: u32) void {
            const byteIndex = index / 8;
            const bitIndex: u3 = @intCast(index % 8);
            this.bitmap[byteIndex] &= ~(@as(u8, 1) << bitIndex);
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
    };
}

pub const BitMapAllocatorPageSize = BitMapAllocatorGeneric(physPageSizes);

var physBitMap = BitMapAllocatorPageSize.initFull(physPageSizes);

pub fn initPmm() void {
    setUsableMemory(&physBitMap);
    virtio.printf("kernel start: 0x{x} kernel end: 0x{x}\n", .{ @intFromPtr(&kernel_start), @intFromPtr(&kernel_end) });
}

fn setUsableMemory(bitMap: *BitMapAllocatorPageSize) void {
    const header = multiboot.multibootInfo;
    const mmm: [*]multiboot.multiboot_mmap_entry = @ptrFromInt(header.mmap_addr);
    for (mmm, 0..(header.mmap_length / @sizeOf(multiboot.multiboot_mmap_entry))) |entry, _| {
        if (entry.type == 1) {
            const start = bitMap.alignUp(@intCast(entry.addr));
            const end = bitMap.alignDown(@intCast(entry.addr + entry.len));
            for ((start / physPageSizes)..(end / physPageSizes)) |index| {
                if (start < physMemStart) {
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
    virtio.printf("usable memory set?: {}\n", .{bitMap});
}
