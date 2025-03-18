const virtio = @import("virtio.zig");

pub const Pde = packed struct {
    present: u1, // P, or 'Present'. If the bit is set, the page is actually in physical memory at the moment.
    read_write: u1, // R/W, the 'Read/Write' permissions flag. If the bit is set, the page is read/write.
    user_supervisor: u1, // U/S, the 'User/Supervisor' bit, controls access to the page based on privilege level.
    write_through: u1, // PWT, controls Write-Through' abilities of the page.
    cache_disabled: u1, // PCD, is the 'Cache Disable' bit. If the bit is set, the page will not be cached.
    accessed: u1, // , or 'Accessed' is used to discover whether a PDE or PTE was read during virtual address translation.
    MINE: u1, // i do whatever i want to store data or something
    page_size: u1 = 0, // 4KiB or 4MiB diffrent struction too
    MINE2: u4, // same as MINE
    address: u20, // the address
};

pub const PdeBig = packed struct {
    present: u1,
    read_write: u1,
    user_supervisor: u1,
    write_through: u1,
    cache_disabled: u1,
    accessed: u1,
    MINE: u1,
    page_size: u1 = 1,
    global: u1,
    MINE2: u3,
    PAT: u1,
    address_high: u8,
    reserved: u1 = 0,
    address_low: u10,
};

pub const Pte = packed struct {
    present: u1,
    read_write: u1,
    user_supervisor: u1,
    write_through: u1,
    cache_disabled: u1,
    accessed: u1,
    dirty: u1,
    PAT: u1,
    global: u1,
    MINE: u3,
    address: u20,
};

extern const kernel_start: u32;
pub const firstHigherHalfPageNumber: u32 = 768;

pub const PageTable = [1024]Pte;
pub const PageDirectory = [1024]Pde;

pub var pageDirectory: PageDirectory align(4096) = Pde{0} ** 1024;
pub var higherHalfPage: PageTable align(4096) = Pte{0} ** 1024;
pub var firstPage: PageTable align(4096) = Pte{0} ** 1024;

fn idPaging(pt: PageTable, vaddr: u32, size: u32) void {
    var pageIdentety: u32 = vaddr & 0xfffff000;
    var index = vaddr >> 12 & 0x3ff;
    var memoryLeftToMap = size;
    while (memoryLeftToMap > 0 and index < 1024) : ({
        pageIdentety += 0x1000;
        index += 1;
        memoryLeftToMap -= 0x1000;
    }) {
        pt[index] = @bitCast(pageIdentety | 1);
    }
}

fn mapHigherHalf(pd: PageDirectory) void {
    var physicalAddress: u32 = @intFromPtr(&kernel_start) & 0xfffff000;
    var index = 0;
    while (index < 1024) : ({
        physicalAddress += 0x1000;
        index += 1;
    }) {
        const page: *PageTable = @ptrFromInt(@as(u32, pd[firstHigherHalfPageNumber - 1].address) << 12);
        page[index] = @bitCast(physicalAddress | 1);
    }
}
