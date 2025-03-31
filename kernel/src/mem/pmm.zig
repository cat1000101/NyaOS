// brain storming: (i am leaveing this here for memories of the easier times)
// get the end of the kernel where there should be free memory that is not under 1MB
// also get the size of the free memory fro mthe bootloader/multiboot
// at the end i align and put the bitmap at the end of the kernel
// fill the bitmap for existing memory
const multiboot = @import("../multiboot.zig");
const virtio = @import("../arch/x86/virtio.zig");
const memory = @import("memory.zig");

fn pageAlignAddress(addr: u32) u32 {
    return addr & ~(memory.physPageSizes - 1);
}
fn pageAlignAddressDown(addr: u32) u32 {
    return pageAlignAddress(addr - memory.physPageSizes);
}
fn pageAlignAddressUp(addr: u32) u32 {
    return pageAlignAddress(addr + memory.physPageSizes);
}

pub const BitMapAllocatorPageSize = memory.BitMapAllocatorGeneric(memory.physPageSizes);

pub var physBitMap = BitMapAllocatorPageSize.init(
    memory.physPageSizes,
    memory.physMemStart,
    memory.physMemStart + (memory.MIB * 3),
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
    defer virtio.printf("finished usable memory setting?\n", .{}); // data: {}\n", .{bitMap});

    const header = multiboot.multibootInfo;
    const mmm: [*]multiboot.multiboot_mmap_entry = @ptrFromInt(header.mmap_addr);
    var endOfMemory: u32 = 0;
    for (mmm, 0..(header.mmap_length / @sizeOf(multiboot.multiboot_mmap_entry))) |entry, _| {
        if (entry.type == 1) {
            const start = bitMap.alignUp(@intCast(entry.addr));
            const end = bitMap.alignDown(@intCast(entry.addr + entry.len));
            endOfMemory = end;
            for ((start / memory.physPageSizes)..(end / memory.physPageSizes)) |index| {
                const address = index * memory.physPageSizes;
                if (address <= memory.physMemStart) {
                    continue;
                } else if ((index - bitMap.start / memory.physPageSizes) >= bitMap.size) {
                    break;
                } else if (address >= @intFromPtr(memory.kernel_physical_start) and address <= @intFromPtr(memory.kernel_physical_end)) {
                    continue;
                }
                bitMap.clear(index - bitMap.start / memory.physPageSizes);
            }
        }
    }
    if (endOfMemory < 8 * memory.physPageSizes * memory.physPageSizes) {
        virtio.printf("you dont have enough memory dummy\n", .{});
        // @panic("you dont have enough memory dummy\n");
    }
}
