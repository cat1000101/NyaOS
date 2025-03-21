const virtio = @import("virtio.zig");

pub const PageDirectoryEntery = packed struct {
    pub const Flags = packed struct {
        present: u1 = 0, // P, or 'Present'. If the bit is set, the page is actually in physical memory at the moment.
        read_write: u1 = 0, // R/W, the 'Read/Write' permissions flag. If the bit is set, the page is read/write.
        user_supervisor: u1 = 0, // U/S, the 'User/Supervisor' bit, controls access to the page based on privilege level.
        write_through: u1 = 0, // PWT, controls Write-Through' abilities of the page.
        cache_disabled: u1 = 0, // PCD, is the 'Cache Disable' bit. If the bit is set, the page will not be cached.
        accessed: u1 = 0, // , or 'Accessed' is used to discover whether a PDE or PTE was read during virtual address translation.
        allocated: u1 = 0, // tells if there is a data structior or not
        page_size: u1 = 0, // 4KiB or 4MiB diffrent struction too
        MINE2: u4 = 0, // same as MINE
    };
    flags: Flags = .{},
    address: u20 = 0, // the address
};

pub const PageDirectoryEnteryBig = packed struct {
    pub const Flags = packed struct {
        present: u1 = 0,
        read_write: u1 = 0,
        user_supervisor: u1 = 0,
        write_through: u1 = 0,
        cache_disabled: u1 = 0,
        accessed: u1 = 0,
        dirty: u1 = 0,
        page_size: u1 = 1,
        global: u1 = 0,
        MINE2: u3 = 0,
        PAT: u1 = 0,
    };
    flags: Flags = .{},
    address_high: u8 = 0,
    reserved: u1 = 0,
    address_low: u10 = 0,
};

pub const PageTableEntery = packed struct {
    pub const Flags = packed struct {
        present: u1 = 0, // P, or 'Present'. If the bit is set, the page is actually in physical memory at the moment.
        read_write: u1 = 0, // R/W, the 'Read/Write' permissions flag. If the bit is set, the page is read/write.
        user_supervisor: u1 = 0, // U/S, the 'User/Supervisor' bit, controls access to the page based on privilege level.
        write_through: u1 = 0, // PWT, controls Write-Through' abilities of the page.
        cache_disabled: u1 = 0, // PCD, is the 'Cache Disable' bit. If the bit is set, the page will not be cached.
        accessed: u1 = 0, // , or 'Accessed' is used to discover whether a PDE or PTE was read during virtual address translation.
        dirty: u1 = 0,
        PAT: u1 = 0,
        global: u1 = 0,
        MINE: u3 = 0,
    };
    flags: Flags = .{},
    address: u20 = 0,
};

pub const AddressSplit = packed struct {
    offset: u12,
    pageEntry: u10,
    directoryEntry: u10,
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
pub const DIR_SIZE: u32 = 4 * MIB;

pub const kernel_physical_start: u32 = 2 * MIB; // @extern(*u32, .{ .name = "kernel_physical_start" });
pub const kernel_physical_end: u32 = 6 * MIB; // @extern(*u32, .{ .name = "kernel_physical_end" });
pub const kernel_start: u32 = 0xC0000000 + kernel_physical_start; // @extern(*u32, .{ .name = "kernel_start" });
pub const kernel_end: u32 = 0xC0000000 + kernel_physical_end; // @extern(*u32, .{ .name = "kernel_end" });
pub const kernel_size_in_4MIB_pages: u32 = 1; //@extern(*u32, .{ .name = "kernel_size_in_4MIB_pages" });
pub const kernel_size_in_4KIB_pages: u32 = 1024; //@extern(*u32, .{ .name = "kernel_size_in_4KIB_pages" });
pub const FIRST_KERNEL_DIR_NUMBER: u32 = kernel_start >> 22;

pub const PageErrors = error{
    NoPage,
    IsBigPage,
    InputNotAligned,
    NotMapped,
};

pub const PageTable = struct {
    entries: [1024]PageTableEntery = [_]PageTableEntery{.{}} ** 1024,

    fn setEntery(self: *PageTable, index: u32, address: u32, flags: PageTableEntery.Flags) void {
        self.entries[index] = PageTableEntery{
            .flags = flags,
            .address = @truncate(address >> 12),
        };
    }
};

pub const PageDirectory = struct {
    const DirectoryEnteryUnion = packed union {
        normal: PageDirectoryEntery,
        big: PageDirectoryEnteryBig,
    };
    entries: [1024]DirectoryEnteryUnion = [_]DirectoryEnteryUnion{.{ .normal = .{} }} ** 1024,

    fn setEntery(self: *PageDirectory, index: u32, pageTable: *PageTable, flags: PageDirectoryEntery.Flags) PageErrors!void {
        self.entries[index].normal = PageDirectoryEntery{
            .flags = flags,
            .address = @truncate(virtualToPhysical(@intFromPtr(pageTable)) catch |err| {
                virtio.printf("can't set normal directory entery at: {} error: {}", .{ index, err });
                return err;
            } >> 12),
        };
    }

    fn setBigEntery(self: PageDirectory, index: u32, address: u32, flags: PageDirectoryEntery.Flags) void {
        self.entries[index].big = PageDirectoryEnteryBig{
            .flags = flags,
            .address_low = @truncate(address >> 22),
            // .address_high = @truncate(address >> 13),
        };
    }

    fn getPageTable(self: *PageDirectory, index: u32) PageErrors!*PageTable {
        if (self.entries[index].normal.flags.allocated == 0) {
            return PageErrors.NoPage;
        } else if (self.entries[index].big.flags.page_size == 1) {
            return PageErrors.IsBigPage;
        } else {
            return @ptrFromInt(@as(u32, self.entries[index].normal.address) << 12);
        }
    }
};

pub var pageDirectory: PageDirectory align(4096) = .{};
pub var higherHalfPage: PageTable align(4096) = .{};
pub var firstPage: PageTable align(4096) = .{};

pub fn initPaging() void {
    pageDirectory.setEntery(0, &firstPage, .{
        .present = 1,
        .read_write = 1,
        .allocated = 1,
    }) catch |err| {
        virtio.printf("Can't set first page table error: {}\n", .{err});
        return;
    };
    pageDirectory.setEntery(FIRST_KERNEL_DIR_NUMBER, &higherHalfPage, .{
        .present = 1,
        .read_write = 1,
        .allocated = 1,
    }) catch |err| {
        virtio.printf("Can't set kernel page table error: {}\n", .{err});
        return;
    };
    idPaging(&pageDirectory, 0, 0, 1 * MIB) catch |err| {
        virtio.printf("Can't id map first page table error: {}\n", .{err});
        return;
    };
    mapHigherHalf(&pageDirectory);
    installPageDirectory(&pageDirectory) catch |err| {
        virtio.printf("Can't install page directory error: {}\n", .{err});
        return;
    };

    virtio.printf("Paging initialized\n", .{});
}

pub fn virtualToPhysical(address: u32) PageErrors!u32 {
    const split: AddressSplit = @bitCast(address);
    const lpageDirectory = getPageDirectory();
    const pageTable = lpageDirectory.getPageTable(split.directoryEntry) catch |err| {
        if (err == PageErrors.IsBigPage) {
            return @intCast((@as(u32, @intCast(lpageDirectory.entries[split.directoryEntry].big.address_low)) << 22) | (@as(u32, @intCast(split.pageEntry)) << 12) | split.offset);
        } else {
            virtio.printf("No page table found for dir: {} error: {}\n", .{ split.directoryEntry, err });
            return PageErrors.NotMapped;
        }
    };
    return @intCast((pageTable.entries[split.pageEntry].address << 12) | split.offset);
}

fn getPageDirectory() *PageDirectory {
    var pd: *PageDirectory = undefined;
    asm volatile (
        \\  mov %cr3, %[pd]
        : [pd] "={eax}" (pd),
    );
    return pd;
}

fn installPageDirectory(pd: *PageDirectory) PageErrors!void {
    const pageDirectoryAddress = virtualToPhysical(@intFromPtr(pd)) catch |err| {
        virtio.printf("Can't get page directory address error: {}\n", .{err});
        return err;
    };
    asm volatile (
        \\  mov %[pageDirectoryAddress], %cr3
        :
        : [pageDirectoryAddress] "{eax}" (pageDirectoryAddress),
    );
}

fn idPaging(pd: *PageDirectory, vaddr: u32, paddr: u32, size: u32) PageErrors!void {
    if (!isAligned(vaddr, PAGE_SIZE) or !isAligned(paddr, PAGE_SIZE) or !isAligned(size, PAGE_SIZE)) {
        return PageErrors.InputNotAligned;
    }
    const fisrtDirEnteryNum: u32 = vaddr >> 22;
    var lpaddr: u32 = paddr;
    var lvaddr: u32 = vaddr;
    var lsize: u32 = size;
    for (fisrtDirEnteryNum..(fisrtDirEnteryNum + (size / DIR_SIZE))) |dirEntryNum| {
        const pageTable: *PageTable = pd.getPageTable(dirEntryNum) catch |err| {
            virtio.printf("No page table found for dir: {} error: {}\n", .{ dirEntryNum, err });
            return;
        };
        while (lvaddr < (dirEntryNum + 1) << 22) : ({
            lpaddr += PAGE_SIZE;
            lvaddr += PAGE_SIZE;
            lsize -= PAGE_SIZE;
        }) {
            pageTable.setEntery((lvaddr >> 12) & 1023, lpaddr, .{ .present = 1, .read_write = 1 });
        }
    }
}

fn mapHigherHalf(pd: *PageDirectory) void {
    const physicalAddress: u32 = kernel_physical_start & 0xfffff000;
    const virtualAddress: u32 = kernel_start & 0xfffff000;
    const size: u32 = kernel_size_in_4KIB_pages * PAGE_SIZE;
    idPaging(pd, virtualAddress, physicalAddress, size) catch |err| {
        virtio.printf("Can't id map higher half error: {}\n", .{err});
        return;
    };
}

pub fn isAligned(address: u32, alignment: u32) bool {
    return (address & (alignment - 1)) == 0;
}
