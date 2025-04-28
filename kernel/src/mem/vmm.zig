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
    // virtualBitMap.debugPrint();
    // testVmmAlloc();
    paging.mapForbiddenZones(multiboot.multibootInfo);

    kmalloc.init();
    debug.infoPrint("vmm initilized\n", .{});
}

pub fn allocatePages(num: usize) ?[*]u8 {
    const page = virtualBitMap.alloc(num) catch |err| {
        debug.errorPrint("vmm.allocatePages:  failed to allocate memory error: {}\n", .{err});
        return null;
    };
    for (0..num) |i| {
        const pageAddr = @intFromPtr(page) + i * memory.PAGE_SIZE;
        if (paging.getPageTableEntryRecursivlyAlways(pageAddr)) |pageTableEntry| {
            if (pageTableEntry.flags.used == 0) {
                pageTableEntry.flags.used = 1;
                debug.debugPrint("vmm.allocatePages:  allocated page at: 0x{X} size: 0x{X}\n", .{ pageAddr, memory.physPageSizes });
            } else {
                debug.errorPrint("vmm.allocatePages:  page is already used\n", .{});
                return null;
            }
        } else |err| {
            if (err == paging.PageErrors.IsBigPage) {
                debug.debugPrint("vmm.allocatePages:  allocated page at: 0x{X} size: 0x{X}\n", .{ pageAddr, memory.physPageSizes });
            } else if (err == paging.PageErrors.NotMapped) {
                const physPage = pmm.physBitMap.alloc(1) catch |physAllocErr| {
                    debug.errorPrint("vmm.allocatePages:  failed to allocate physical page error: {}\n", .{physAllocErr});
                    return null;
                };
                const physPageAddr = @intFromPtr(physPage);
                _ = paging.setPageTableEntryRecursivlyAlways(pageAddr, physPageAddr, .{
                    .present = 1,
                    .read_write = 1,
                    .used = 1,
                }) catch |setErr| {
                    debug.errorPrint("vmm.allocatePages:  failed to set page table entry: {}\n", .{setErr});
                    return null;
                };
                debug.debugPrint("vmm.allocatePages:  allocated page at: 0x{X} size: 0x{X}\n", .{ pageAddr, memory.physPageSizes });
            } else {
                debug.errorPrint("vmm.allocatePages:  failed to get page table, error: {}\n\n", .{err});
                return null;
            }
        }
    }
    return page;
}

pub fn freePages(address: [*]u8, num: usize) !void {
    defer virtualBitMap.free(address, num);
    for (0..num) |i| {
        const physAddr = paging.virtualToPhysical(@intFromPtr(address) + i * memory.PAGE_SIZE) catch |err| {
            debug.errorPrint("vmm.freePage:  failed to get physical address: {}\n", .{err});
            return err;
        };
        pmm.physBitMap.free(@ptrFromInt(physAddr), 1);
        paging.setPageTableEntryRecursivlyAlways(@intFromPtr(address) + i * memory.PAGE_SIZE, 0, .{}) catch |setErr| {
            debug.errorPrint("vmm.allocatePage:  failed to set page table entry: {}\n", .{setErr});
            return setErr;
        };
    }
}

// idk need to check this latter was having brain damage when trying to do something similar without reason ; -;
pub fn mapVirtualAddressRange(virtualAddr: u32, size: u32) ?[]u8 {
    if (!memory.isAligned(virtualAddr, memory.PAGE_SIZE)) {
        debug.errorPrint("vmm.mapVirtualAddressRange:  virtual address is not aligned virtualAddr: 0x{X}\n", .{
            virtualAddr,
        });
        return null;
    }
    // if (size >= memory.DIR_SIZE * 2) {
    //     const lsize = memory.alignAddressUp(size, memory.DIR_SIZE);
    //     const physicalAddr: u32 = @intFromPtr(pmm.physBitMap.alloc(lsize / memory.PAGE_SIZE) catch |err| {
    //         debug.errorPrint("vmm.mapVirtualAddressRange:  failed to allocate physical memory: {}\n", .{err});
    //         return null;
    //     });
    //     errdefer {
    //         pmm.physBitMap.free(@ptrFromInt(physicalAddr), lsize / memory.PAGE_SIZE);
    //     }
    //     paging.idBigPagesRecursivly(virtualAddr, physicalAddr, lsize, true) catch |err| {
    //         debug.errorPrint("vmm.mapVirtualAddressRange:  failed to big id map virtual address range: {}\n", .{err});
    //         return null;
    //     };
    // } else {
    const lsize = memory.alignAddressUp(size, memory.PAGE_SIZE);
    const physicalAddr: u32 = @intFromPtr(pmm.physBitMap.alloc(lsize / memory.PAGE_SIZE) catch |err| {
        debug.errorPrint("vmm.mapVirtualAddressRange:  failed to allocate physical memory: {}\n", .{err});
        return null;
    });

    paging.idPagesRecursivly(virtualAddr, physicalAddr, lsize, true) catch |err| {
        debug.errorPrint("vmm.mapVirtualAddressRange:  failed to id map virtual address range: {}\n", .{err});
        pmm.physBitMap.free(@ptrFromInt(physicalAddr), lsize / memory.PAGE_SIZE);
        return null;
    };
    // }
    const memoryRangeSlice = @as([*]u8, @ptrFromInt(virtualAddr))[0..lsize];
    @memset(memoryRangeSlice, 0);
    return memoryRangeSlice;
}

fn testVmmAlloc() void {
    debug.infoPrint("vmm.testVmmAlloc:  start test\n", .{});
    const page = allocatePages(2) orelse {
        debug.errorPrint("vmm.testVmmAlloc:  failed to allocate memory\n", .{});
        return;
    };
    const pageAddr = @intFromPtr(page);
    page[0] = 69;
    debug.infoPrint("vmm.testVmmAlloc: success:  allocated address: 0x{X} first byte: {}\n", .{ pageAddr, page[0] });
    freePages(page, 2);
}
