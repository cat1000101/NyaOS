const virtio = @import("virtio.zig");
const pmm = @import("../../mem/pmm.zig");
const boot = @import("../../main.zig");

pub const PageDirectoryEntery = packed struct {
    pub const Flags = packed struct {
        present: u1 = 0, // P, or 'Present'. If the bit is set, the page is actually in physical memory at the moment.
        read_write: u1 = 0, // R/W, the 'Read/Write' permissions flag. If the bit is set, the page is read/write.
        user_supervisor: u1 = 0, // U/S, the 'User/Supervisor' bit, controls access to the page based on privilege level.
        write_through: u1 = 0, // PWT, controls Write-Through' abilities of the page.
        cache_disabled: u1 = 0, // PCD, is the 'Cache Disable' bit. If the bit is set, the page will not be cached.
        accessed: u1 = 0, // , or 'Accessed' is used to discover whether a PDE or PTE was read during virtual address translation.
        reserved: u1 = 0, // reserved
        page_size: u1 = 0, // 4KiB or 4MiB diffrent struction too
        reserved2: u4 = 0, // same as reserved
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
        reserved2: u3 = 0,
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
        reserved: u3 = 0,
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
// pub const DENTRY_ALLOCATED: u32 = 0x40;
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
// pub const TENTRY_ALLOCATED: u32 = 0x200;
// pub const TENTRY_AVAILABLE: u32 = 0xC00;
pub const TENTRY_PAGE_ADDR: u32 = 0xFFFFF000;

pub const GIB: usize = 0x40000000;
pub const MIB: usize = 0x100000;
pub const KIB: usize = 0x400;

pub const PAGE_SIZE: u32 = 4 * KIB;
pub const DIR_SIZE: u32 = 4 * MIB;

pub const kernel_physical_start: u32 = 2 * MIB; // @extern(*u32, .{ .name = "kernel_physical_start" });
pub const kernel_physical_end: u32 = 4 * MIB; // @extern(*u32, .{ .name = "kernel_physical_end" });
pub const kernel_start: u32 = 0xC0000000 + kernel_physical_start; // @extern(*u32, .{ .name = "kernel_start" });
pub const kernel_end: u32 = 0xC0000000 + kernel_physical_end; // @extern(*u32, .{ .name = "kernel_end" });
pub const kernel_size_in_4MIB_pages: u32 = 1; //@extern(*u32, .{ .name = "kernel_size_in_4MIB_pages" });
pub const kernel_size_in_4KIB_pages: u32 = 512; //@extern(*u32, .{ .name = "kernel_size_in_4KIB_pages" });
pub const FIRST_KERNEL_DIR_NUMBER: u32 = kernel_start >> 22;

const PAGE_TABLE_BASE = 0xFFC00000;
const PAGE_DIRECTORY_VIRTUAL = 0xFFFFF000;

pub const PageErrors = error{
    NoPage,
    IsBigPage,
    InputNotAligned,
    NotMapped,
};

pub const PageTable = struct {
    entries: [1024]PageTableEntery = [_]PageTableEntery{.{}} ** 1024,

    fn setEntery(self: *PageTable, index: u32, address: u32, flags: PageTableEntery.Flags) void {
        const entry: PageTableEntery = @bitCast(@as(u32, @intCast(@as(u12, @bitCast(flags)))) | address);
        self.entries[index] = entry;
    }
};

pub const PageDirectory = struct {
    const DirectoryEnteryUnion = packed union {
        normal: PageDirectoryEntery,
        big: PageDirectoryEnteryBig,
    };
    entries: [1024]DirectoryEnteryUnion = [_]DirectoryEnteryUnion{.{ .normal = .{} }} ** 1024,
    tables: [1024]*PageTable = [_]*PageTable{undefined} ** 1024,

    fn setEntery(self: *PageDirectory, index: u32, pageTable: *PageTable, flags: PageDirectoryEntery.Flags) PageErrors!void {
        const physicalPageAddress: u32 = virtualToPhysical(@intFromPtr(pageTable)) catch |err| {
            virtio.printf("PageDirectory.setEntery:  can't set normal directory entery at: #{} error: {}\n", .{ index, err });
            return err;
        };
        const inputAddress: u20 = @truncate(physicalPageAddress >> 12);
        self.entries[index].normal = PageDirectoryEntery{
            .flags = flags,
            .address = inputAddress,
        };
        self.tables[index] = pageTable;
    }

    fn setBigEntery(self: *PageDirectory, index: u32, address: u32, flags: PageDirectoryEntery.Flags) void {
        self.entries[index].big = PageDirectoryEnteryBig{
            .flags = flags,
            .address_low = @truncate(address >> 22),
        };
    }

    fn mapPage(self: *PageDirectory, vaddr: u32, paddr: u32, flags: PageTableEntery.Flags) PageErrors!void {
        const pageTableIndex = (vaddr >> 12) & 1023;
        const pageDirectoryIndex = vaddr >> 22;
        const pageTable = self.getPageTable(pageDirectoryIndex) catch |err| {
            virtio.printf("mapVirtualPage:  Can't get page table error: {}\n", .{err});
            return err;
        };
        pageTable.setEntery(pageTableIndex, paddr, flags);
    }

    fn mapVirtualPage(self: *PageDirectory, vaddr: u32, paddr: u32, flags: PageTableEntery.Flags) PageErrors!void {
        const pageTableIndex = (vaddr >> 12) & 1023;
        const pageTable = self.getVirtualPageTable(vaddr) catch |err| {
            virtio.printf("mapVirtualPage:  Can't get page table error: {}\n", .{err});
            return err;
        };
        pageTable.setEntery(pageTableIndex, paddr, flags);
    }

    /// returns VIRTUAL address of the page table as pointer
    fn getPageTable(self: *PageDirectory, index: u32) PageErrors!*PageTable {
        if (@as(u32, @bitCast(self.entries[index].normal)) == 0) {
            return PageErrors.NoPage;
        } else if (self.entries[index].big.flags.page_size == 1) {
            return PageErrors.IsBigPage;
        } else {
            return self.tables[index];
        }
    }

    /// should only be used at the early stages of paging
    fn idPages(self: *PageDirectory, vaddr: u32, paddr: u32, size: u32) PageErrors!void {
        if (!isAligned(vaddr, PAGE_SIZE) or !isAligned(paddr, PAGE_SIZE) or !isAligned(size, PAGE_SIZE)) {
            virtio.printf("idVirtualPages:  idPaging input not aligned\n", .{});
            return PageErrors.InputNotAligned;
        }
        var lpaddr: u32 = paddr;
        var lvaddr: u32 = vaddr;
        var lsize: u32 = size;
        while (lsize > 0) : ({
            lpaddr += PAGE_SIZE;
            lvaddr += PAGE_SIZE;
            lsize -= PAGE_SIZE;
        }) {
            self.mapPage(lvaddr, lpaddr, .{ .present = 1, .read_write = 1 }) catch |err| {
                virtio.printf("idVirtualPages:  Can't map virtual page error: {}\n", .{err});
                return err;
            };
        }
    }

    /// should only be used when using this page directory as the current page directory
    /// returns VIRTUAL address of the page table
    fn getVirtualPageTable(self: *PageDirectory, address: u32) PageErrors!*PageTable {
        const pageDirIndex = address >> 22;
        const pageTableAddress = PAGE_TABLE_BASE + (pageDirIndex << 12);
        if (@as(u32, @bitCast(self.entries[pageDirIndex].normal)) == 0) {
            return PageErrors.NoPage;
        } else if (self.entries[pageDirIndex].big.flags.page_size == 1) {
            return PageErrors.IsBigPage;
        }
        const pageTable: *PageTable = @ptrFromInt(pageTableAddress);
        return pageTable;
    }

    fn idVirtualPages(self: *PageDirectory, vaddr: u32, paddr: u32, size: u32) PageErrors!void {
        if (!isAligned(vaddr, PAGE_SIZE) or !isAligned(paddr, PAGE_SIZE) or !isAligned(size, PAGE_SIZE)) {
            virtio.printf("idVirtualPages:  idPaging input not aligned\n", .{});
            return PageErrors.InputNotAligned;
        }
        var lpaddr: u32 = paddr;
        var lvaddr: u32 = vaddr;
        var lsize: u32 = size;
        while (lsize > 0) : ({
            lpaddr += PAGE_SIZE;
            lvaddr += PAGE_SIZE;
            lsize -= PAGE_SIZE;
        }) {
            self.mapVirtualPage(lvaddr, lpaddr, .{ .present = 1, .read_write = 1 }) catch |err| {
                virtio.printf("idVirtualPages:  Can't map virtual page error: {}\n", .{err});
                return err;
            };
        }
    }
};

pub var pageDirectory: PageDirectory align(4096) = .{};
pub var higherHalfPage: PageTable align(4096) = .{};
pub var firstPage: PageTable align(4096) = .{};

const pageDirectoryPtr: *PageDirectory = &pageDirectory;
const higherHalfPagePtr: *PageTable = &higherHalfPage;
const firstPagePtr: *PageTable = &firstPage;

pub fn initPaging() void {
    virtio.printf("Initializing paging\n", .{});
    defer virtio.printf("Paging initialized\n", .{});

    pageDirectory.setEntery(1023, @ptrCast(pageDirectoryPtr), .{
        .present = 1,
        .read_write = 1,
    }) catch |err| {
        virtio.printf("Can't set recursive page table error: {}\n", .{err});
        return;
    };
    pageDirectoryPtr.setEntery(0, firstPagePtr, .{
        .present = 1,
        .read_write = 1,
    }) catch |err| {
        virtio.printf("Can't set first page table error: {}\n", .{err});
        return;
    };
    pageDirectoryPtr.setEntery(FIRST_KERNEL_DIR_NUMBER, higherHalfPagePtr, .{
        .present = 1,
        .read_write = 1,
    }) catch |err| {
        virtio.printf("Can't set kernel page table error: {}\n", .{err});
        return;
    };
    pageDirectoryPtr.idPages(0, 0, 4 * MIB) catch |err| {
        virtio.printf("Can't id map first page table error: {}\n", .{err});
        return;
    };
    mapHigherHalf(pageDirectoryPtr);

    // debugPrintPaging();

    installPageDirectory(pageDirectoryPtr) catch |err| {
        virtio.printf("Can't install page directory error: {}\n", .{err});
        return;
    };

    testPaging();
}

pub fn virtualToPhysical(address: u32) PageErrors!u32 {
    const split: AddressSplit = @bitCast(address);
    const lpageDirectory = getPageDirectory();
    const pageTable = lpageDirectory.getVirtualPageTable(address) catch |err| {
        if (err == PageErrors.IsBigPage) {
            return @intCast((@as(u32, @intCast(lpageDirectory.entries[split.directoryEntry].big.address_low)) << 22) | (@as(u32, @intCast(split.pageEntry)) << 12) | split.offset);
        } else {
            virtio.printf("virtualToPhysical:  No page table found for dir: {} error: {}\n", .{ split.directoryEntry, err });
            return PageErrors.NotMapped;
        }
    };
    return (@as(u32, pageTable.entries[split.pageEntry].address) << 12) | split.offset;
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
    virtio.printf("Installing page directory\n", .{});
    defer virtio.printf("Page directory installed\n", .{});
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

fn forceTLBFlush() void {
    asm volatile (
        \\  mov %cr3, %eax
        \\  mov %eax, %cr3
    );
}

fn invalidatePage(address: u32) void {
    asm volatile (
        \\  invlpg %[address]
        :
        : [address] "{eax}" (address),
    );
}

fn mapHigherHalf(pd: *PageDirectory) void {
    virtio.printf("map higher half kernel\n", .{});
    defer virtio.printf("higher half kernel mapped\n", .{});
    const physicalAddress: u32 = kernel_physical_start & 0xfffff000;
    const virtualAddress: u32 = kernel_start & 0xfffff000;
    const size: u32 = kernel_size_in_4KIB_pages * PAGE_SIZE;
    pd.idPages(virtualAddress, physicalAddress, size) catch |err| {
        virtio.printf("Can't id map higher half error: {}\n", .{err});
        return;
    };
}

pub fn isAligned(address: u32, alignment: u32) bool {
    return (address & (alignment - 1)) == 0;
}

fn debugPrintPaging() void {
    const lpageDirectory = getPageDirectory();
    virtio.printf("page directory physical address: 0x{x} virtual address: 0x{x}\n", .{ virtualToPhysical(@intFromPtr(&lpageDirectory)) catch blk: {
        break :blk 0x6969;
    }, @intFromPtr(&lpageDirectory) });
    for (lpageDirectory.entries, lpageDirectory.tables, 0..1024) |entery, table, i| {
        if (@as(u32, @bitCast(entery.normal)) == 0) {
            continue;
        }
        for (table.entries, 0..1024) |lPTE, j| {
            if (@as(u32, @bitCast(lPTE)) == 0) {
                continue;
            }
            virtio.printf("debugPrintPaging:  directory entry: #{} info: 0x{x}\ndebugPrintPaging:  page entry: #{} info: 0x{x}\n", .{
                i,
                @as(u32, @bitCast(entery.normal)),
                j,
                @as(u32, @bitCast(lPTE)),
            });
        }
    }
}

var testPageTable: PageTable align(4096) = .{};
const testPageTablePtr: *PageTable = &testPageTable;

fn testPaging() void {
    virtio.printf("testing paging by allocating a page and changing it's content\n", .{});
    defer virtio.printf("paging test done\n", .{});
    const physicalPage: u32 = pmm.physBitMap.allocate() catch |err| {
        virtio.printf("Can't allocate page error: {}\n", .{err});
        return;
    };
    testPageTablePtr.setEntery(0, physicalPage, .{ .present = 1, .read_write = 1 });
    testPageTablePtr.setEntery(1, physicalPage, .{ .present = 1, .read_write = 1 });
    const lpageDirectory = getPageDirectory();
    const pageDirectoryIndex = 55;
    const lvaddr0: u32 = 55 * DIR_SIZE + 4;
    const lvaddr1: u32 = 55 * DIR_SIZE + PAGE_SIZE + 4;
    lpageDirectory.setEntery(pageDirectoryIndex, testPageTablePtr, .{ .present = 1, .read_write = 1 }) catch |err| {
        virtio.printf("Can't set test page table error: {}\n", .{err});
        return;
    };
    forceTLBFlush();
    // debugPrintPaging();
    const lptr0: [*]u32 = @ptrFromInt(lvaddr0);
    const lptr1: [*]u32 = @ptrFromInt(lvaddr1);
    lptr0[0] = 0x6969;
    if (lptr1[0] == 0x6969) {
        virtio.printf("paging test passed lptr0: 0x{x} and lptr1: 0x{x}\n", .{ lptr0[0], lptr1[0] });
    } else {
        virtio.printf("paging test failed\n", .{});
    }
}
