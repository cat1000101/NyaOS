const mem = @import("std").mem;
const virtio = @import("../arch/x86/virtio.zig");
const multiboot = @import("../multiboot.zig");
const paging = @import("../arch/x86/paging.zig");
const memory = @import("memory.zig");
const pmm = @import("pmm.zig");
const acpi = @import("../drivers/acpi.zig");

var tempBuffer: [memory.PAGE_SIZE]u8 = [_]u8{0xff} ** memory.PAGE_SIZE;
var tempBufferSlice: []u8 = &tempBuffer;

pub var virtualBitMap: memory.BitMapAllocatorGeneric = undefined;

pub fn initVmm() void {
    paging.initPaging();

    virtualBitMap = memory.BitMapAllocatorGeneric.init(
        tempBufferSlice,
        memory.physPageSizes,
        @intFromPtr(memory.kernel_end),
        paging.RECURSIVE_PAGE_TABLE_BASE,
        false,
    );
    // vpageAllocator.debugPrint();
    // testVmmAlloc();
    paging.mapForbiddenZones(multiboot.multibootInfo);
}

pub fn allocatePage() ?[*]u8 {
    const page = virtualBitMap.alloc(1) catch |err| {
        virtio.printf("vmm.allocatePage:  failed to allocate memory error: {}\n", .{err});
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
            const physPage = pmm.physBitMap.alloc(1) catch |physAllocErr| {
                virtio.printf("vmm.allocatePage:  failed to allocate physical page error: {}\n", .{physAllocErr});
                return null;
            };
            const physPageAddr = @intFromPtr(physPage);
            _ = paging.setPageTableEntryRecursivly(pageAddr, physPageAddr, .{
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

pub fn freePage(address: [*]u8) void {
    const physAddr = paging.virtualToPhysical(@intFromPtr(address)) catch |err| {
        virtio.printf("vmm.freePage:  failed to get physical address: {}\n", .{err});
        return;
    };
    pmm.physBitMap.free(@ptrFromInt(physAddr), 1);

    _ = paging.setPageTableEntryRecursivly(@intFromPtr(address), 0, .{}) catch |setErr| {
        virtio.printf("vmm.allocatePage:  failed to set page table entry: {}\n", .{setErr});
    };
    virtualBitMap.free(address, 1);
}

fn testVmmAlloc() void {
    virtio.printf("vmm.testVmmAlloc:  start test\n", .{});
    const page = allocatePage() orelse {
        virtio.printf("vmm.testVmmAlloc:  failed to allocate memory\n", .{});
        return;
    };
    const pageAddr = @intFromPtr(page);
    page[0] = 69;
    virtio.printf("vmm.testVmmAlloc: success:  allocated address: 0x{X} first byte: {}\n", .{ pageAddr, page[0] });
    freePage(page);
}
