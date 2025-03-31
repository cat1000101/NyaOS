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
    true,
);

pub fn initPmm() void {
    physBitMap.setUsableMemory(multiboot.multibootInfo);
    testPageAllocator(&physBitMap);
}

fn testPageAllocator(allocator: *BitMapAllocatorPageSize) void {
    const testAllocation = allocator.allocate() catch {
        virtio.printf("failed to allocate memory\n", .{});
        return;
    };
    allocator.free(testAllocation);
}
