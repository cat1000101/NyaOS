// brain storming: (i am leaveing this here for memories of the easier times)
// get the end of the kernel where there should be free memory that is not under 1MB
// also get the size of the free memory fro mthe bootloader/multiboot
// at the end i align and put the bitmap at the end of the kernel
// fill the bitmap for existing memory
const multiboot = @import("../multiboot.zig");
const memory = @import("memory.zig");

const log = @import("std").log;

var tempBuffer: [memory.PAGE_SIZE]u8 = [_]u8{0xff} ** memory.PAGE_SIZE;
var tempBufferSlice: []u8 = &tempBuffer;

pub var physBitMap: memory.BitMapAllocatorGeneric = undefined;

pub fn initPmm() void {
    physBitMap = memory.BitMapAllocatorGeneric.init(
        tempBufferSlice,
        memory.physPageSizes,
        memory.MIB * 4,
        memory.MIB * 32,
        false,
    );
    // physBitMap.debugPrint();
    // testPageAllocator();
    log.info("pmm initilized\n", .{});
}

pub fn testPageAllocator() void {
    const testAllocation = physBitMap.alloc(1) catch |err| {
        log.err("pmm.testPageAllocator:  failed to allocate memory error: {}\n", .{err});
        return;
    };
    log.debug("pmm.testPageAllocator:  allocated memory at: 0x{X} size: 0x{X}\n", .{
        @intFromPtr(testAllocation),
        physBitMap.allocationSize,
            // @import("std").mem.sliceAsBytes(memory).len,
    });
    physBitMap.free(testAllocation, 1);
}
