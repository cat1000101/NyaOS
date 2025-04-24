const debug = @import("../arch/x86/debug.zig");
const multiboot = @import("../multiboot.zig");
const paging = @import("../arch/x86/paging.zig");
const memory = @import("memory.zig");
const pmm = @import("pmm.zig");
const kmalloc = @import("kmalloc.zig");

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

    kmalloc.init();
}

pub fn allocatePages(num: usize) ?[*]u8 {
    const page = virtualBitMap.alloc(num) catch |err| {
        debug.printf("vmm.allocatePages:  failed to allocate memory error: {}\n", .{err});
        return null;
    };
    for (0..num) |i| {
        const pageAddr = @intFromPtr(page) + i * memory.PAGE_SIZE;
        if (paging.getPageTableEntryRecursivlyAlways(pageAddr)) |pageTableEntry| {
            if (pageTableEntry.flags.used == 0) {
                pageTableEntry.flags.used = 1;
                // debug.printf("vmm.allocatePages:  allocated page at: 0x{X} size: 0x{X}\n", .{ pageAddr, memory.physPageSizes });
            } else {
                debug.printf("vmm.allocatePages:  page is already used\n", .{});
                return null;
            }
        } else |err| {
            if (err == paging.PageErrors.IsBigPage) {
                // debug.printf("vmm.allocatePages:  allocated page at: 0x{X} size: 0x{X}\n", .{ pageAddr, memory.physPageSizes });
            } else if (err == paging.PageErrors.NotMapped) {
                const physPage = pmm.physBitMap.alloc(1) catch |physAllocErr| {
                    debug.printf("vmm.allocatePages:  failed to allocate physical page error: {}\n", .{physAllocErr});
                    return null;
                };
                const physPageAddr = @intFromPtr(physPage);
                _ = paging.setPageTableEntryRecursivlyAlways(pageAddr, physPageAddr, .{
                    .present = 1,
                    .read_write = 1,
                    .used = 1,
                }) catch |setErr| {
                    debug.printf("vmm.allocatePages:  failed to set page table entry: {}\n", .{setErr});
                    return null;
                };
                // debug.printf("vmm.allocatePages:  allocated page at: 0x{X} size: 0x{X}\n", .{ pageAddr, memory.physPageSizes });
            } else {
                debug.printf("vmm.allocatePages:  failed to get page table, error: {}\n\n", .{err});
                return null;
            }
        }
    }
    return page;
}

pub fn freePages(address: [*]u8, num: usize) void {
    for (0..num) |i| {
        const physAddr = paging.virtualToPhysical(@intFromPtr(address) + i * memory.PAGE_SIZE) catch |err| {
            debug.printf("vmm.freePage:  failed to get physical address: {}\n", .{err});
            return;
        };
        pmm.physBitMap.free(@ptrFromInt(physAddr), 1);
        paging.setPageTableEntryRecursivly(@intFromPtr(address) + i * memory.PAGE_SIZE, 0, .{}) catch |setErr| {
            debug.printf("vmm.allocatePage:  failed to set page table entry: {}\n", .{setErr});
        };
    }
    virtualBitMap.free(address, num);
}

pub fn mapVirtualAddressRange(virtualAddr: u32, physicalAddr: u32, size: u32) void {
    if (size >= memory.DIR_SIZE * 2) {
        paging.idBigPagesRecursivly(virtualAddr, physicalAddr, memory.alignAddressUp(size - 1, memory.DIR_SIZE), true) catch |err| {
            debug.printf("vmm.mapVirtualAddressRange:  failed to big id map virtual address range: {}\n", .{err});
        };
    } else {
        paging.idPagesRecursivly(virtualAddr, physicalAddr, memory.alignAddressUp(size - 1, memory.PAGE_SIZE), true) catch |err| {
            debug.printf("vmm.mapVirtualAddressRange:  failed to id map virtual address range: {}\n", .{err});
        };
    }
}

fn testVmmAlloc() void {
    debug.printf("vmm.testVmmAlloc:  start test\n", .{});
    const page = allocatePages(2) orelse {
        debug.printf("vmm.testVmmAlloc:  failed to allocate memory\n", .{});
        return;
    };
    const pageAddr = @intFromPtr(page);
    page[0] = 69;
    debug.printf("vmm.testVmmAlloc: success:  allocated address: 0x{X} first byte: {}\n", .{ pageAddr, page[0] });
    freePages(page, 2);
}
