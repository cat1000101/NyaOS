const virtio = @import("virtio.zig");

pub const PageDirectoryEntery = packed struct {
    flags: PageDirectoryEnteryFlags = .{},
    allocated: u1 = 0, // tells if there is a data structior or not
    page_size: u1 = 0, // 4KiB or 4MiB diffrent struction too
    MINE2: u4 = 0, // same as MINE
    address: u20 = 0, // the address
};

pub const PageDirectoryEnteryFlags = packed struct {
    present: u1 = 0, // P, or 'Present'. If the bit is set, the page is actually in physical memory at the moment.
    read_write: u1 = 0, // R/W, the 'Read/Write' permissions flag. If the bit is set, the page is read/write.
    user_supervisor: u1 = 0, // U/S, the 'User/Supervisor' bit, controls access to the page based on privilege level.
    write_through: u1 = 0, // PWT, controls Write-Through' abilities of the page.
    cache_disabled: u1 = 0, // PCD, is the 'Cache Disable' bit. If the bit is set, the page will not be cached.
    accessed: u1 = 0, // , or 'Accessed' is used to discover whether a PDE or PTE was read during virtual address translation.
};

pub const PageDirectoryEnteryBig = packed struct {
    flags: PageDirectoryEnteryFlagsBig = .{},
    address_high: u8 = 0,
    reserved: u1 = 0,
    address_low: u10 = 0,
};

pub const PageDirectoryEnteryFlagsBig = packed struct {
    present: u1 = 0,
    read_write: u1 = 0,
    user_supervisor: u1 = 0,
    write_through: u1 = 0,
    cache_disabled: u1 = 0,
    accessed: u1 = 0,
    MINE: u1 = 0,
    page_size: u1 = 1,
    global: u1 = 0,
    MINE2: u3 = 0,
    PAT: u1 = 0,
};

pub const PageTableEntery = packed struct {
    flags: PageTableEnteryFlags = .{},
    allocated: u1 = 0, // tells if there is a data structior or not
    MINE: u2 = 0,
    address: u20 = 0,
};

pub const PageTableEnteryFlags = packed struct {
    present: u1 = 0, // P, or 'Present'. If the bit is set, the page is actually in physical memory at the moment.
    read_write: u1 = 0, // R/W, the 'Read/Write' permissions flag. If the bit is set, the page is read/write.
    user_supervisor: u1 = 0, // U/S, the 'User/Supervisor' bit, controls access to the page based on privilege level.
    write_through: u1 = 0, // PWT, controls Write-Through' abilities of the page.
    cache_disabled: u1 = 0, // PCD, is the 'Cache Disable' bit. If the bit is set, the page will not be cached.
    accessed: u1 = 0, // , or 'Accessed' is used to discover whether a PDE or PTE was read during virtual address translation.
    dirty: u1 = 0,
    PAT: u1 = 0,
    global: u1 = 0,
};

// stolen from https://github.com/ZystemOS/pluto
// The bitmasks for the bits in a DirectoryEntry
pub const DENTRY_PRESENT: u32 = 0x1;
pub const DENTRY_READ_WRITE: u32 = 0x2;
pub const DENTRY_USER: u32 = 0x4;
pub const DENTRY_WRITE_THROUGH: u32 = 0x8;
pub const DENTRY_CACHE_DISABLED: u32 = 0x10;
pub const DENTRY_ACCESSED: u32 = 0x20;
pub const DENTRY_ALLOCATED: u32 = 0x40;
pub const DENTRY_4MB_PAGES: u32 = 0x80;
pub const DENTRY_IGNORED: u32 = 0x100;
pub const DENTRY_AVAILABLE: u32 = 0xE00;
pub const DENTRY_PAGE_ADDR: u32 = 0xFFFFF000;

// The bitmasks for the bits in a TableEntry
pub const TENTRY_PRESENT: u32 = 0x1;
pub const TENTRY_READ_WRITE: u32 = 0x2;
pub const TENTRY_USER: u32 = 0x4;
pub const TENTRY_WRITE_THROUGH: u32 = 0x8;
pub const TENTRY_CACHE_DISABLED: u32 = 0x10;
pub const TENTRY_ACCESSED: u32 = 0x20;
pub const TENTRY_DIRTY: u32 = 0x40;
pub const TENTRY_ZERO: u32 = 0x80;
pub const TENTRY_GLOBAL: u32 = 0x100;
pub const TENTRY_ALLOCATED: u32 = 0x200;
pub const TENTRY_AVAILABLE: u32 = 0xC00;
pub const TENTRY_PAGE_ADDR: u32 = 0xFFFFF000;

pub const GIB: usize = 0x40000000;
pub const MIB: usize = 0x100000;
pub const KIB: usize = 0x400;

pub const PAGE_SIZE: u32 = 4 * KIB;
pub const BIG_PAGE_SIZE: u32 = 4 * MIB;

pub const kernel_physical_start: u32 = 2 * MIB; // @extern(*u32, .{ .name = "kernel_physical_start" });
pub const kernel_physical_end: u32 = 4 * MIB; // @extern(*u32, .{ .name = "kernel_physical_end" });
pub const kernel_start: u32 = 0xC0000000 + kernel_physical_start; // @extern(*u32, .{ .name = "kernel_start" });
pub const kernel_end: u32 = 0xC0000000 + kernel_physical_end; // @extern(*u32, .{ .name = "kernel_end" });
pub const kernel_size_in_4MIB_pages: u32 = 1; //@extern(*u32, .{ .name = "kernel_size_in_4MIB_pages" });
pub const kernel_size_in_4KIB_pages: u32 = 1024; //@extern(*u32, .{ .name = "kernel_size_in_4KIB_pages" });
pub const FIRST_KERNEL_DIR_NUMBER: u32 = kernel_start >> 22;

pub const PageErrors = error{
    NoPage,
    IsBigPage,
};

pub const PageTable = [1024]PageTableEntery;
pub const PageDirectory = [1024]PageDirectoryEntery;

pub var pageDirectory: PageDirectory align(4096) = [_]PageDirectoryEntery{.{}} ** 1024;
pub var higherHalfPage: PageTable align(4096) = [_]PageTableEntery{.{}} ** 1024;
pub var firstPage: PageTable align(4096) = [_]PageTableEntery{.{}} ** 1024;

pub fn initPaging() void {
    setPageDirectoryEntery(&pageDirectory, 0, &firstPage, .{ .present = 1, .read_write = 1 });
    setPageDirectoryEntery(&pageDirectory, FIRST_KERNEL_DIR_NUMBER, &higherHalfPage, .{ .present = 1, .read_write = 1 });
    idPaging(&pageDirectory, 0, 4 * MIB);
    mapHigherHalf(&pageDirectory);
    installPageDirectory(&pageDirectory);

    virtio.printf("Paging initialized\n", .{});
}

pub fn virtualToPhysical(address: u32) u32 {
    const page = address >> 12;
    const offset = address & 0xfff;
    const directoryIndex = (page >> 10) & 1023;
    const pageIndex = page & 1023;
    const lpageDirectory = getPageDirectory();
    const pageTable = getPageTableFromPageDirectory(lpageDirectory, directoryIndex) catch |err| {
        if (err == PageErrors.IsBigPage) {
            return (lpageDirectory[directoryIndex].address << 12) + offset;
        } else {
            virtio.printf("No page table found for page: {} error: {}\n", .{ page, err });
            return 0;
        }
    };
    return (pageTable[pageIndex].address << 12) + offset;
}

pub fn getPageDirectory() *PageDirectory {
    var pd: *PageDirectory = undefined;
    asm volatile (
        \\  mov %cr3, %[pd]
        : [pd] "={eax}" (pd),
    );
    return pd;
}

fn installPageDirectory(pd: *PageDirectory) void {
    const pageDirectoryAddress = virtualToPhysical(@intFromPtr(pd));
    asm volatile (
        \\  mov %[pageDirectoryAddress], %cr3
        :
        : [pageDirectoryAddress] "{eax}" (pageDirectoryAddress),
    );
}

fn setPageEntery(page: *PageTable, index: u32, address: u32, flags: PageTableEnteryFlags) void {
    page[index] = PageTableEntery{
        .flags = flags,
        .address = @truncate(address >> 12),
    };
}

fn setPageDirectoryEntery(pd: *PageDirectory, index: u32, pageTable: *PageTable, flags: PageDirectoryEnteryFlags) void {
    pd[index] = PageDirectoryEntery{
        .flags = flags,
        .address = @truncate(virtualToPhysical(@intFromPtr(pageTable)) >> 12),
    };
}

fn setPageDirectoryEnteryBig(pd: PageDirectory, index: u32, address: u32, flags: PageDirectoryEnteryFlagsBig) void {
    pd[index] = PageDirectoryEnteryBig{
        .flags = flags,
        .address_low = @truncate(address >> 12),
        .address_high = @truncate(address >> 32),
    };
}

fn getPageTableFromPageDirectory(pd: *PageDirectory, index: u32) PageErrors!*PageTable {
    if (pd[index].allocated == 0) {
        return PageErrors.NoPage;
    } else if (pd[index].page_size == 1) {
        return PageErrors.IsBigPage;
    }
    return @ptrFromInt(@as(u32, pd[index].address) << 12);
}

fn idPaging(pd: *PageDirectory, addr: u32, size: u32) void {
    var physicalAddress: u32 = addr & 0xfffff000;
    const startPage: u32 = addr >> 22;
    for (startPage..(startPage + (size / PAGE_SIZE))) |page| {
        var index: usize = 0;
        const idPage: *PageTable = getPageTableFromPageDirectory(pd, page >> 10) catch |err| {
            virtio.printf("No page table found for page: {} error: {}\n", .{ page, err });
            return;
        };
        while (index < (page & 1024)) : ({
            physicalAddress += 0x1000;
            index += 1;
        }) {
            setPageEntery(idPage, index, physicalAddress, @bitCast(@as(u9, @truncate(TENTRY_READ_WRITE | TENTRY_PRESENT))));
        }
    }
}

fn mapHigherHalf(pd: *PageDirectory) void {
    var physicalAddress: u32 = kernel_physical_start & 0xfffff000;
    for (0..kernel_size_in_4KIB_pages) |page| {
        var index: usize = 0;
        const kernelPage: *PageTable = getPageTableFromPageDirectory(pd, FIRST_KERNEL_DIR_NUMBER + (page >> 10)) catch |err| {
            virtio.printf("No page table found for page: {} error: {}\n", .{ page, err });
            return;
        };
        while (index < (page & 1024)) : ({
            physicalAddress += 0x1000;
            index += 1;
        }) {
            setPageEntery(kernelPage, index, physicalAddress, .{ .present = 1, .read_write = 1 });
        }
    }
}
