const virtio = @import("../arch/x86/virtio.zig");
const multiboot = @import("../multiboot.zig");
const paging = @import("../arch/x86/paging.zig");
const memory = @import("memory.zig");
const pmm = @import("pmm.zig");
const acpi = @import("../drivers/acpi.zig");

const vpageAllocatorType = memory.BitMapAllocatorGeneric(memory.physPageSizes);
var vpageAllocator: vpageAllocatorType = undefined;

pub fn initVmm() void {
    paging.initPaging();

    vpageAllocator = vpageAllocatorType.init(
        memory.physPageSizes,
        @intFromPtr(memory.kernel_end),
        paging.RECURSIVE_PAGE_TABLE_BASE,
        false,
    );
    vpageAllocator.setUsableMemory(multiboot.multibootInfo);
    // vpageAllocator.debugPrint();
    // testVmmAlloc();
    paging.mapForbiddenZones(multiboot.multibootInfo);
}

pub fn allocatePage() ?[*]u8 {
    const page = vpageAllocator.allocate() catch {
        virtio.printf("vmm.allocatePage:  failed to allocate memory\n", .{});
        return null;
    };
    const pageAddr = @intFromPtr(page);
    if (paging.getPageTableEntryRecursivly(pageAddr)) |pageTableEntry| {
        if (pageTableEntry.flags.used == 0) {
            pageTableEntry.flags.used = 1;
            virtio.printf("vmm.allocatePage:  allocated page at: 0x{X} size: 0x{X}\n", .{ pageAddr, memory.physPageSizes });
            return page;
        } else {
            virtio.printf("vmm.allocatePage:  page is already used\n", .{});
            return null;
        }
    } else |err| {
        if (err == paging.PageErrors.IsBigPage) {
            virtio.printf("vmm.allocatePage:  allocated page at: 0x{X} size: 0x{X}\n", .{ pageAddr, memory.physPageSizes });
            return page;
        } else if (err == paging.PageErrors.NotMapped) {
            const physPage = @intFromPtr(pmm.rawAllocate() catch |allocatePhysErr| {
                virtio.printf("vmm.allocatePage:  failed to allocate physical page: {}\n", .{allocatePhysErr});
                return null;
            });
            _ = paging.setPageTableEntryRecursivly(pageAddr, physPage, .{
                .present = 1,
                .read_write = 1,
                .used = 1,
            }) catch |setErr| {
                virtio.printf("vmm.allocatePage:  failed to set page table entry: {}\n", .{setErr});
                return null;
            };
            virtio.printf("vmm.allocatePage:  allocated page at: 0x{X} size: 0x{X}\n", .{ pageAddr, memory.physPageSizes });
            return page;
        } else {
            virtio.printf("vmm.allocatePage:  failed to get page table, error: {}\n\n", .{err});
            return null;
        }
    }
}

pub fn free(address: [*]u8) void {
    _ = paging.setPageTableEntryRecursivly(@intFromPtr(address), 0, .{}) catch |setErr| {
        virtio.printf("vmm.allocatePage:  failed to set page table entry: {}\n", .{setErr});
    };
    vpageAllocator.free(address);
}

fn testVmmAlloc() void {
    virtio.printf("testing vmm alloc:  start test\n", .{});
    const page = allocatePage() orelse {
        virtio.printf("testVmmAlloc:  failed to allocate memory\n", .{});
        return;
    };
    const pageAddr = @intFromPtr(page);
    page[0] = 69;
    virtio.printf("testing vmm alloc success:  allocated address: 0x{X} first byte: {}\n", .{ pageAddr, page[0] });
    free(page);
}
