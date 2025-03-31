const virtio = @import("../arch/x86/virtio.zig");
const paging = @import("../arch/x86/paging.zig");
const memory = @import("memory.zig");

const vpageAllocatorType = memory.BitMapAllocatorGeneric(memory.physPageSizes);
pub var vpageAllocator: vpageAllocatorType = undefined;

pub fn initVmm() void {
    paging.initPaging();

    vpageAllocator = vpageAllocatorType.init(
        memory.physPageSizes,
        @intFromPtr(memory.kernel_end),
        paging.RECURSIVE_PAGE_TABLE_BASE,
    );
}
