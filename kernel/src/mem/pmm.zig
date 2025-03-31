// brain storming: (i am leaveing this here for memories of the easier times)
// get the end of the kernel where there should be free memory that is not under 1MB
// also get the size of the free memory fro mthe bootloader/multiboot
// at the end i align and put the bitmap at the end of the kernel
// fill the bitmap for existing memory
const multiboot = @import("../multiboot.zig");
const virtio = @import("../arch/x86/virtio.zig");
const memory = @import("memory.zig");

const BitMapAllocatorPageSize = memory.BitMapAllocatorGeneric(memory.physPageSizes);
var physBitMap = BitMapAllocatorPageSize.init(
    memory.physPageSizes,
    memory.MIB * 4,
    memory.MIB * 8,
    true,
);

pub fn initPmm() void {
    physBitMap.setUsableMemory(multiboot.multibootInfo);
    // testPageAllocator(&physBitMap);
}

pub fn allocate() ?[*]u8 {
    const page = physBitMap.allocate() catch {
        virtio.printf("failed to allocate memory\n", .{});
        return null;
    };
    return page;
}
pub fn rawAllocate() ![*]u8 {
    return physBitMap.allocate();
}

pub fn free(page: [*]u8) void {
    physBitMap.free(page);
}

fn testPageAllocator(allocator: *BitMapAllocatorPageSize) void {
    const testAllocation = allocator.allocate() catch {
        virtio.printf("failed to allocate memory\n", .{});
        return;
    };
    allocator.free(testAllocation);
}
