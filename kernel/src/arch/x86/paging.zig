const debug = @import("debug.zig");
const pmm = @import("../../mem/pmm.zig");
const vmm = @import("../../mem/vmm.zig");
const boot = @import("../../main.zig");
const memory = @import("../../mem/memory.zig");
const multiboot = @import("../../multiboot.zig");

// stolen from https://github.com/ZystemOS/pluto
// The bitmasks for the bits in a DirectoryEntry
pub const DENTRY_PRESENT: u32 = 0x1;
pub const DENTRY_READ_WRITE: u32 = 0x2;
pub const DENTRY_USER: u32 = 0x4;
pub const DENTRY_WRITE_THROUGH: u32 = 0x8;
pub const DENTRY_CACHE_DISABLED: u32 = 0x10;
pub const DENTRY_ACCESSED: u32 = 0x20;
pub const DENTRY_DIRTY: u32 = 0x40;
pub const DENTRY_4MB_PAGES: u32 = 0x80;
pub const DENTRY_IGNORED: u32 = 0x100; // in big it is global in normal ones it is aviable, so we ignore it
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
pub const TENTRY_AVIABLE: u32 = 0xE00;
pub const TENTRY_PAGE_ADDR: u32 = 0xFFFFF000;

pub const FIRST_KERNEL_DIR_NUMBER: u32 = memory.KERNEL_ADDRESS_SPACE >> 22;
pub const RECURSIVE_PAGE_TABLE_BASE: u32 = 0xFFC00000;
pub const RECURSIVE_PAGE_DIRECTORY_ADDRESS: u32 = 0xFFFFF000;

pub const PageErrors = error{
    NoPage,
    IsBigPage,
    InputNotAligned,
    NotMapped,
    OnlyDirectDirectoryAllowed,
    Used,
};

pub const PageDirectoryEntry = packed struct {
    pub const Flags = packed struct {
        /// P, or 'Present'. If the bit is set, the page is actually in physical memory at the moment.
        present: u1 = 0,
        /// R/W, the 'Read/Write' permissions flag. If the bit is set, the page is read/write.
        read_write: u1 = 0,
        /// U/S, the 'User/Supervisor' bit, controls access to the page based on privilege level.
        user_supervisor: u1 = 0,
        /// PWT, controls Write-Through' abilities of the page.
        write_through: u1 = 0,
        /// PCD, is the 'Cache Disable' bit. If the bit is set, the page will not be cached.
        cache_disabled: u1 = 0,
        /// , or 'Accessed' is used to discover whether a PDE or PTE was read during virtual address translation.
        accessed: u1 = 0,
        /// diry bit that is reserved on amd processors and ignored on intel so i treat it as reserved source: @khitiara
        dirty: u1 = 0,
        /// 4KiB or 4MiB diffrent struction too
        page_size: u1 = 0,
        /// same as reserved
        MINE: u4 = 0,
    };
    flags: Flags = .{},
    address: u20 = 0, // the address
};

pub const PageDirectoryEntryBig = packed struct {
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
        used: u1 = 0,
        MINE: u2 = 0,
        PAT: u1 = 0,
    };
    flags: Flags = .{},
    address_high: u8 = 0,
    reserved: u1 = 0,
    address_low: u10 = 0,
};
pub const PageTableEntry = packed struct {
    pub const Flags = packed struct {
        /// P, or 'Present'. If the bit is set, the page is actually in physical memory at the moment.
        present: u1 = 0,
        /// R/W, the 'Read/Write' permissions flag. If the bit is set, the page is read/write.
        read_write: u1 = 0,
        /// U/S, the 'User/Supervisor' bit, controls access to the page based on privilege level.
        user_supervisor: u1 = 0,
        /// PWT, controls Write-Through' abilities of the page.
        write_through: u1 = 0,
        /// PCD, is the 'Cache Disable' bit. If the bit is set, the page will not be cached.
        cache_disabled: u1 = 0,
        /// , or 'Accessed' is used to discover whether a PDE or PTE was read during virtual address translation.
        accessed: u1 = 0,
        dirty: u1 = 0,
        PAT: u1 = 0,
        global: u1 = 0,
        used: u1 = 0,
        MINE: u2 = 0,
    };
    flags: Flags = .{},
    address: u20 = 0,
};

pub const AddressSplit = packed struct {
    offset: u12,
    pageEntry: u10,
    directoryEntry: u10,
};

pub const PageTable = struct {
    entries: [1024]PageTableEntry = [_]PageTableEntry{.{}} ** 1024,

    pub fn setEntery(self: *PageTable, index: u32, address: u32, flags: PageTableEntry.Flags) void {
        const entry: PageTableEntry = .{
            .address = @truncate(address >> 12),
            .flags = flags,
        };
        self.entries[index] = entry;
    }

    pub fn getEntery(self: *PageTable, index: u32) PageErrors!*PageTableEntry {
        if (@as(u32, @bitCast(self.entries[index])) == 0) {
            return PageErrors.NotMapped;
        }
        return &self.entries[index];
    }
};

pub const PageDirectory = struct {
    const DirectoryEnteryUnion = packed union {
        normal: PageDirectoryEntry,
        big: PageDirectoryEntryBig,
    };
    entries: [1024]DirectoryEnteryUnion = [_]DirectoryEnteryUnion{.{ .normal = .{} }} ** 1024,
    tables: [1024]*PageTable = [_]*PageTable{undefined} ** 1024,

    fn setEntery(self: *PageDirectory, index: u32, pageTable: *PageTable, flags: PageDirectoryEntry.Flags) PageErrors!void {
        const physicalPageAddress: u32 = virtualToPhysical(@intFromPtr(pageTable)) catch |err| {
            debug.errorPrint("PageDirectory.setEntery:  can't set normal directory entery at: #{} error: {}\n", .{ index, err });
            return err;
        };
        debug.debugPrint("PageDirectory.setEntery:  set page directory entry, page addr: 0x{X} vaddr: 0x{X}, governing memory: 0x{X}, flags: {any}\n", .{
            physicalPageAddress,
            @intFromPtr(pageTable),
            index << 22,
            flags,
        });
        self.entries[index].normal = PageDirectoryEntry{
            .flags = flags,
            .address = @truncate(physicalPageAddress >> 12),
        };
        self.tables[index] = pageTable;
    }

    fn setBigEntery(self: *PageDirectory, index: u32, address: u32, flags: PageDirectoryEntry.Flags) void {
        self.entries[index].big = PageDirectoryEntryBig{
            .flags = flags,
            .address_low = @truncate(address >> 22),
        };
    }

    /// should only be used with the page directory directly and not the RECURSIVE_PAGE_TABLE_BASE or RECURSIVE_PAGE_DIRECTORY_ADDRESS
    fn mapPageEntery(self: *PageDirectory, vaddr: u32, paddr: u32, flags: PageTableEntry.Flags) PageErrors!void {
        if (!isDirectDirectory(self)) {
            debug.errorPrint("PageDirectory.mapPageEntery:  self is recursive pageDirectory\n", .{});
            return PageErrors.OnlyDirectDirectoryAllowed;
        }
        const pageTableIndex = (vaddr >> 12) & 1023;
        const pageDirectoryIndex = vaddr >> 22;
        const pageTable = self.getPageTable(pageDirectoryIndex) catch |err| {
            debug.errorPrint("PageDirectory.mapPageEntery:  Can't get page table error: {}\n", .{err});
            return err;
        };
        pageTable.setEntery(pageTableIndex, paddr, flags);
    }

    /// should only be used with the page directory directly and not the RECURSIVE_PAGE_TABLE_BASE or RECURSIVE_PAGE_DIRECTORY_ADDRESS
    /// returns VIRTUAL address of the page table as pointer
    fn getPageTable(self: *PageDirectory, index: u32) PageErrors!*PageTable {
        if (!isDirectDirectory(self)) {
            debug.errorPrint("PageDirectory.getPageTable:  self is recursive pageDirectory\n", .{});
            return PageErrors.OnlyDirectDirectoryAllowed;
        }
        if (@as(u32, @bitCast(self.entries[index].normal)) == 0) {
            return PageErrors.NoPage;
        } else if (self.entries[index].big.flags.page_size == 1) {
            return PageErrors.IsBigPage;
        } else {
            return self.tables[index];
        }
    }

    /// should only be used with the page directory directly and not the RECURSIVE_PAGE_TABLE_BASE or RECURSIVE_PAGE_DIRECTORY_ADDRESS
    fn idPages(self: *PageDirectory, vaddr: u32, paddr: u32, size: u32, used: bool) PageErrors!void {
        if (!isDirectDirectory(self)) {
            debug.errorPrint("PageDirectory.idPages:  self is recursive pageDirectory\n", .{});
            return PageErrors.OnlyDirectDirectoryAllowed;
        }
        if (!isAligned(vaddr, memory.PAGE_SIZE) or !isAligned(paddr, memory.PAGE_SIZE) or !isAligned(size, memory.PAGE_SIZE)) {
            debug.errorPrint("PageDirectory.idPages:  idPaging input not aligned\n", .{});
            return PageErrors.InputNotAligned;
        }
        var lpaddr: u32 = paddr;
        var lvaddr: u32 = vaddr;
        var lsize: u32 = size;
        debug.debugPrint("PageDirectory.idPages:  idPaging vaddr: 0x{X} paddr: 0x{X} size: 0x{X}\n", .{ lvaddr, lpaddr, lsize });
        while (lsize > 0) : ({
            lpaddr += memory.PAGE_SIZE;
            lvaddr += memory.PAGE_SIZE;
            lsize -= memory.PAGE_SIZE;
        }) {
            self.mapPageEntery(lvaddr, lpaddr, .{ .present = 1, .read_write = 1, .used = @intFromBool(used) }) catch |err| {
                debug.errorPrint("PageDirectory.idPages:  Can't map virtual page error: {}\n", .{err});
                return err;
            };
        }
    }
};

pub fn newPageTable(vaddr: u32) memory.AllocatorError!*PageTable {
    debug.debugPrint("++allocates new page table\n", .{});
    defer debug.debugPrint("--allocated new page table\n", .{});

    const physPage = pmm.physBitMap.alloc(1) catch |err| {
        debug.errorPrint("newPageTable:  failed to allocate physical page error: {}\n", .{err});
        return err;
    };
    const physPageAddress = @intFromPtr(physPage);
    const pageIndex = (vaddr >> 22);
    const pageTable = setPageTableRecursivly(pageIndex, physPageAddress, .{
        .present = 1,
        .read_write = 1,
        .user_supervisor = if (vaddr < memory.KERNEL_ADDRESS_SPACE) 1 else 0,
    });

    const pageTablePtr: *[memory.PAGE_SIZE]u8 = @ptrCast(pageTable);
    @memset(pageTablePtr, 0);

    return pageTable;
}

/// will free everything assosieted with a pageTable
pub fn freePageTableRecursivly(pageAddr: u32) void {
    debug.debugPrint("++free page table and it's insides\n", .{});
    defer debug.debugPrint("--freed page table and it's insides\n", .{});

    const split: AddressSplit = @bitCast(pageAddr);
    var pageTable: *PageTable = undefined;
    var lvaddr: u32 = 0;
    if (pageAddr < RECURSIVE_PAGE_TABLE_BASE) {
        const lpageDirectory = getPageDirectoryRecursivly();
        const directoryEntry = lpageDirectory.entries[split.directoryEntry].normal;
        if (@as(u32, @bitCast(directoryEntry)) == 0) {
            debug.errorPrint("freePageTableRecursivly:  page directory entry is empty\n", .{});
            return;
        }
        pageTable = getPageTableRecursivly(split.directoryEntry);
        lvaddr = @as(u32, split.directoryEntry) << 22;
    } else {
        pageTable = @ptrFromInt(pageAddr);
    }
    var pageTableIndex: usize = 0;
    debug.debugPrint("freePageTableRecursivly:  start freeing page table entry at: 0x{X}, pageTableIndex: 0x{X}\n", .{ lvaddr, pageTableIndex });
    while (pageTableIndex < 1024) : ({
        pageTableIndex += 1;
        lvaddr += memory.PAGE_SIZE;
    }) {
        const entry = pageTable.entries[pageTableIndex];
        if (entry.flags.used == 1) {
            const address: u32 = @as(u32, entry.address) << 12;
            debug.debugPrint("freePageTableRecursivly:  freeing page table entry at: 0x{X}, paddr: 0x{X} entry: {any}\n", .{ lvaddr, address, entry });
            pageTable.entries[pageTableIndex] = .{};
            pmm.physBitMap.free(@ptrFromInt(address), 1);
            if (lvaddr >= memory.KERNEL_ADDRESS_SPACE and pageAddr < RECURSIVE_PAGE_TABLE_BASE) {
                vmm.virtualBitMap.free(@ptrFromInt(lvaddr), 1);
            }
        }
    }
}

/// should only be used when using kernel space page directory as the current page directory
pub fn setPageTableRecursivly(index: u32, pageTablePhysAddress: u32, flags: PageDirectoryEntry.Flags) *PageTable {
    const lpageDirectory: *PageDirectory = getPageDirectoryRecursivly();
    const entry = PageDirectoryEntry{
        .address = @truncate(pageTablePhysAddress >> 12),
        .flags = flags,
    };
    lpageDirectory.entries[index].normal = entry;

    const pageTable: *PageTable = getPageTableRecursivly(index);

    invalidatePage(@intFromPtr(pageTable));
    invalidatePage(RECURSIVE_PAGE_DIRECTORY_ADDRESS);

    return pageTable;
}

pub fn setBigEntryRecursivly(vaddr: u32, paddr: u32, flags: PageDirectoryEntryBig.Flags) PageErrors!void {
    const split: AddressSplit = @bitCast(vaddr);
    const lpageDirectory: *PageDirectory = getPageDirectoryRecursivly();
    const entry = PageDirectoryEntryBig{
        .address_low = @truncate(paddr >> 22),
        .flags = flags,
    };
    if ((lpageDirectory.entries[split.directoryEntry].big.flags.page_size == 1 and lpageDirectory.entries[split.directoryEntry].big.flags.used == 0) or (@as(u32, @bitCast(lpageDirectory.entries[split.directoryEntry].normal)) == 0)) {
        lpageDirectory.entries[split.directoryEntry].big = entry;
        invalidatePage(RECURSIVE_PAGE_DIRECTORY_ADDRESS);
        invalidatePage(vaddr);
    } else {
        return PageErrors.Used;
    }
}

/// should only be used when using kernel space page directory as the current page directory
/// will always try to return page table and if it doesnt exist it will allocate and make a new one
pub fn getPageTableRecursivlyAlways(index: u32) !*PageTable {
    const lpageDirectory: *PageDirectory = getPageDirectoryRecursivly();
    const pageTableAddress = RECURSIVE_PAGE_TABLE_BASE + (index << 12);
    const pageTable: *PageTable = @ptrFromInt(pageTableAddress);
    if (@as(u32, @bitCast(lpageDirectory.entries[index].normal)) == 0) {
        return newPageTable(index << 22) catch |err| {
            debug.errorPrint("getPageTableRecursivlyAlways:  Can't create new page table, error: {}\n", .{err});
            return err;
        };
    } else if (lpageDirectory.entries[index].big.flags.page_size == 1) {
        debug.debugPrint("getPageTableRecursivlyAlways:  page table is big page\n", .{});
        return PageErrors.IsBigPage;
    }
    return pageTable;
}

/// should only be used when using kernel space page directory as the current page directory
/// /// will always try to set page table entry and if it doesnt exist it will allocate and make a new one
pub fn setPageTableEntryRecursivlyAlways(vaddr: u32, paddr: u32, flags: PageTableEntry.Flags) !void {
    const split: AddressSplit = @bitCast(vaddr);
    const pageTable = getPageTableRecursivlyAlways(split.directoryEntry) catch |err| {
        debug.errorPrint("setPageTableEntryRecursivlyAlways:  Can't get page table, error: {}\n", .{err});
        return err;
    };
    pageTable.setEntery(split.pageEntry, paddr, flags);
    invalidatePage(vaddr);
}

/// will always try to return page table entry and if it doesnt exist it will allocate and make a new one
pub fn getPageTableEntryRecursivlyAlways(vaddr: u32) !*PageTableEntry {
    const split: AddressSplit = @bitCast(vaddr);
    const pageTable = getPageTableRecursivlyAlways(split.directoryEntry) catch |err| {
        debug.errorPrint("getPageTableEntryRecursivlyAlways:  Can't get page table, error: {}\n", .{err});
        return err;
    };
    return pageTable.getEntery(split.pageEntry);
}

pub fn getPageDirectoryEntryDefualtFlags(vaddr: usize) PageDirectoryEntry.Flags {
    return PageDirectoryEntry.Flags{
        .present = 1,
        .read_write = 1,
        .user_supervisor = if (vaddr < memory.KERNEL_ADDRESS_SPACE) 1 else 0,
    };
}

pub fn getBigPageDirectoryEntryDefualtFlags(vaddr: usize, used: bool) PageDirectoryEntryBig.Flags {
    return PageDirectoryEntryBig.Flags{
        .present = 1,
        .read_write = 1,
        .used = @intFromBool(used),
        .user_supervisor = if (vaddr < memory.KERNEL_ADDRESS_SPACE) 1 else 0,
    };
}

pub fn getPageTableEntryDefualtFlags(vaddr: usize, used: bool) PageTableEntry.Flags {
    return PageTableEntry.Flags{
        .present = 1,
        .read_write = 1,
        .used = @intFromBool(used),
        .user_supervisor = if (vaddr < memory.KERNEL_ADDRESS_SPACE) 1 else 0,
    };
}

/// should only be used when using kernel space page directory as the current page directory
pub fn idPagesRecursivly(vaddr: u32, paddr: u32, size: u32, used: bool) !void {
    debug.debugPrint("++id pages recursivly\n", .{});
    defer debug.debugPrint("--mapped id pages recursivly\n", .{});

    if (!isAligned(vaddr, memory.PAGE_SIZE) or !isAligned(paddr, memory.PAGE_SIZE) or !isAligned(size, memory.PAGE_SIZE)) {
        debug.errorPrint("idPagesRecursivly:  idPaging input not aligned\n", .{});
        return PageErrors.InputNotAligned;
    }
    var lpaddr: u32 = paddr;
    var lvaddr: u32 = vaddr;
    var lsize: u32 = size;
    debug.debugPrint("idPagesRecursivly:  idPaging vaddr: 0x{X} paddr: 0x{X} size: 0x{X}\n", .{ lvaddr, lpaddr, lsize });
    while (lsize > 0) : ({
        lpaddr += memory.PAGE_SIZE;
        lvaddr += memory.PAGE_SIZE;
        lsize -= memory.PAGE_SIZE;
    }) {
        setPageTableEntryRecursivlyAlways(
            lvaddr,
            lpaddr,
            getPageTableEntryDefualtFlags(lvaddr, used),
        ) catch |err| {
            debug.errorPrint("idPagesRecursivly:  Can't map virtual page, error: {}\n", .{err});
            return err;
        };
    }
}

pub fn idBigPagesRecursivly(vaddr: u32, paddr: u32, size: u32, used: bool) !void {
    debug.debugPrint("++big id pages recursivly\n", .{});
    defer debug.debugPrint("--mapped big id pages recursivly\n", .{});

    if (!isAligned(vaddr, memory.DIR_SIZE) or !isAligned(paddr, memory.DIR_SIZE) or !isAligned(size, memory.DIR_SIZE)) {
        debug.errorPrint("idBigPagesRecursivly:  idPaging input not aligned\n", .{});
        return PageErrors.InputNotAligned;
    }
    var lpaddr: u32 = paddr;
    var lvaddr: u32 = vaddr;
    var lsize: u32 = size;
    debug.debugPrint("idBigPagesRecursivly:  idPaging vaddr: 0x{X} paddr: 0x{X} size: 0x{X}\n", .{ lvaddr, lpaddr, lsize });
    while (lsize > 0) : ({
        lpaddr += memory.DIR_SIZE;
        lvaddr += memory.DIR_SIZE;
        lsize -= memory.DIR_SIZE;
    }) {
        setBigEntryRecursivly(
            lvaddr,
            lpaddr,
            getBigPageDirectoryEntryDefualtFlags(lvaddr, used),
        ) catch |err| {
            debug.errorPrint("idBigPagesRecursivly:  Can't map virtual page, error: {}\n", .{err});
            return err;
        };
    }
}

pub fn getPageDirectoryRecursivly() *PageDirectory {
    const lpageDirectory: *PageDirectory = @ptrFromInt(RECURSIVE_PAGE_DIRECTORY_ADDRESS);
    return lpageDirectory;
}

pub fn getPageTableRecursivly(index: usize) *PageTable {
    const pageTableAddress: u32 = RECURSIVE_PAGE_TABLE_BASE + (index << 12);
    const pageTable: *PageTable = @ptrFromInt(pageTableAddress);
    return pageTable;
}

pub fn getPageDirectoryEntryRecursivly(index: usize) PageDirectoryEntry {
    const lpageDirectory: *PageDirectory = getPageDirectoryRecursivly();
    return lpageDirectory.entries[index].normal;
}

pub fn getPageTableEntryRecursivly(pageIndex: usize, entryIndex: usize) PageTableEntry {
    const pageTable = getPageTableRecursivly(pageIndex);
    return pageTable.entries[entryIndex];
}

fn isDirectDirectory(directory: *PageDirectory) bool {
    const address: u32 = @intFromPtr(directory);
    return address > memory.KERNEL_ADDRESS_SPACE and address < RECURSIVE_PAGE_TABLE_BASE;
}

pub fn getCr3() *PageDirectory {
    var pd: *PageDirectory = undefined;
    asm volatile (
        \\  mov %cr3, %[pd]
        : [pd] "={eax}" (pd),
    );
    return pd;
}

pub var pageDirectory: PageDirectory align(4096) = .{};
var higherHalfPage: PageTable align(4096) = .{};
var firstPage: PageTable align(4096) = .{};

pub const kernelPageDirectory: *PageDirectory = &pageDirectory;
const higherHalfPagePtr: *PageTable = &higherHalfPage;
const firstPagePtr: *PageTable = &firstPage;

pub fn initPaging() void {
    debug.infoPrint("Initializing paging\n", .{});
    defer debug.infoPrint("Paging initialized\n", .{});

    pageDirectory.setEntery(1023, @ptrCast(kernelPageDirectory), .{
        .present = 1,
        .read_write = 1,
    }) catch |err| {
        debug.errorPrint("initPaging:  Can't set recursive page table error: {}\n", .{err});
        return;
    };
    kernelPageDirectory.setEntery(0, firstPagePtr, .{
        .present = 1,
        .read_write = 1,
    }) catch |err| {
        debug.errorPrint("initPaging:  Can't set first page table error: {}\n", .{err});
        return;
    };
    kernelPageDirectory.setEntery(FIRST_KERNEL_DIR_NUMBER, higherHalfPagePtr, .{
        .present = 1,
        .read_write = 1,
    }) catch |err| {
        debug.errorPrint("initPaging:  Can't set kernel page table error: {}\n", .{err});
        return;
    };
    kernelPageDirectory.idPages(0, 0, 4 * memory.MIB, true) catch |err| {
        debug.errorPrint("initPaging:  Can't id map first page table error: {}\n", .{err});
        return;
    };
    mapHigherHalf(kernelPageDirectory);

    // debugPrintPaging(pageDirectoryPtr);

    installPageDirectory(kernelPageDirectory) catch |err| {
        debug.errorPrint("initPaging:  Can't install page directory error: {}\n", .{err});
        return;
    };

    // testPaging();
}

pub fn virtualToPhysical(address: u32) PageErrors!u32 {
    const split: AddressSplit = @bitCast(address);
    const lpageDirectory: *PageDirectory = getPageDirectoryRecursivly();
    if (getPageTableRecursivlyAlways(split.directoryEntry)) |pageTable| {
        return (@as(u32, pageTable.entries[split.pageEntry].address) << 12) | split.offset;
    } else |err| {
        if (err == PageErrors.IsBigPage) {
            return @intCast((@as(u32, @intCast(lpageDirectory.entries[split.directoryEntry].big.address_low)) << 22) | (@as(u32, @intCast(split.pageEntry)) << 12) | split.offset);
        } else {
            debug.errorPrint("virtualToPhysical:  No page table found for dir: {}, error: {}\n", .{ split.directoryEntry, err });
            return PageErrors.NotMapped;
        }
    }
}

fn installPageDirectory(pd: *PageDirectory) PageErrors!void {
    debug.debugPrint("++Installing page directory\n", .{});
    defer debug.debugPrint("--Page directory installed\n", .{});

    const pageDirectoryAddress = virtualToPhysical(@intFromPtr(pd)) catch |err| {
        debug.errorPrint("installPageDirectory:  Can't get page directory address error: {}\n", .{err});
        return err;
    };
    asm volatile (
        \\  mov %[pageDirectoryAddress], %cr3
        :
        : [pageDirectoryAddress] "{eax}" (pageDirectoryAddress),
    );
}

pub inline fn setCr3(pd: *PageDirectory) void {
    asm volatile (
        \\  mov %[pd], %cr3
        :
        : [pd] "{eax}" (pd),
    );
}

inline fn forceTLBFlush() void {
    asm volatile (
        \\  mov %cr3, %eax
        \\  mov %eax, %cr3
    );
}

inline fn invalidatePage(address: u32) void {
    asm volatile (
        \\  invlpg (%[address])
        :
        : [address] "r" (address),
    );
}

pub fn isAligned(address: u32, alignment: u32) bool {
    return (address & (alignment - 1)) == 0;
}

fn mapHigherHalf(pd: *PageDirectory) void {
    debug.debugPrint("++map higher half kernel\n", .{});
    defer debug.debugPrint("--higher half kernel mapped\n", .{});

    const size: u32 = (@intFromPtr(memory.kernel_end) - memory.KERNEL_ADDRESS_SPACE + memory.PAGE_SIZE) & 0xfffff000;
    pd.idPages(memory.KERNEL_ADDRESS_SPACE, 0, size, true) catch |err| {
        debug.errorPrint("mapHigherHalf:  Can't id map higher half error: {}\n", .{err});
        return;
    };
}

pub fn mapForbiddenZones(mbh: *multiboot.multiboot_info) void {
    debug.debugPrint("++map forbidden zones\n", .{});
    defer debug.debugPrint("--forbidden zones mapped\n", .{});

    const header = mbh;
    const memorySize: u32 = header.mem_upper * 1024 + 1 * memory.MIB;
    debug.infoPrint("usable ram size: 0x{X}\n", .{memorySize});
    const mmm: [*]multiboot.multiboot_mmap_entry = @ptrFromInt(header.mmap_addr);
    for (mmm, 0..(header.mmap_length / @sizeOf(multiboot.multiboot_mmap_entry))) |entry, _| {
        const entryLen: u32 = @as(u32, @truncate(entry.len));
        const paddr: u32 = @as(u32, @truncate(entry.addr));
        const entryEnd = @addWithOverflow(paddr, entryLen);
        if (entry.type == 1) {
            continue;
        } else if (entryEnd[0] >= RECURSIVE_PAGE_DIRECTORY_ADDRESS or entryEnd[1] == 1) {
            continue;
        } else if (entryLen >= memory.DIR_SIZE) {
            idBigPagesRecursivly(paddr, paddr, entryLen, true) catch |err| {
                debug.errorPrint("mapForbiddenZones:  Can't big id map forbidden zone error: {}\n", .{err});
            };
            continue;
        }
        idPagesRecursivly(
            memory.alignAddress(paddr, memory.PAGE_SIZE),
            memory.alignAddress(paddr, memory.PAGE_SIZE),
            memory.alignAddressUp(entryLen - 1, memory.PAGE_SIZE),
            true,
        ) catch |err| {
            debug.errorPrint("mapForbiddenZones:  Can't id map forbidden zone error: {}\n", .{err});
            return;
        };
    }
}

fn testPaging() void {
    debug.debugPrint("++testing paging by allocating a page and changing it's content\n", .{});
    defer debug.debugPrint("--paging test done\n", .{});

    const physicalPage: u32 = @intFromPtr(pmm.physBitMap.alloc(1) catch |err| {
        debug.errorPrint("testPaging:  Can't allocate page for test: {}\n", .{err});
        return;
    });
    const lvaddr = 55 * memory.DIR_SIZE;
    const testPageTablePtr = newPageTable(lvaddr) catch |err| {
        debug.errorPrint("testPaging:  Can't create test page table error: {}\n", .{err});
        return;
    };
    defer freePageTableRecursivly(@intFromPtr(testPageTablePtr));

    testPageTablePtr.setEntery(0, physicalPage, .{ .present = 1, .read_write = 1, .used = 1 });
    testPageTablePtr.setEntery(1, physicalPage, .{ .present = 1, .read_write = 1, .used = 1 });
    forceTLBFlush();

    const lvaddr0: u32 = lvaddr + 4;
    const lvaddr1: u32 = lvaddr + memory.PAGE_SIZE + 4;
    const lptr0: [*]u32 = @ptrFromInt(lvaddr0);
    const lptr1: [*]u32 = @ptrFromInt(lvaddr1);

    lptr0[0] = 0x6969;
    if (lptr1[0] == 0x6969) {
        debug.infoPrint("testPaging:  paging test passed lptr0: 0x{X} and lptr1: 0x{X}\n", .{ lptr0[0], lptr1[0] });
    } else {
        debug.infoPrint("testPaging:  paging test failed\n", .{});
    }
}

fn debugPrintPaging(pd: *PageDirectory) void {
    debug.debugPrint("++debug printing pages\n", .{});
    defer debug.debugPrint("--debug printing pages done\n", .{});

    const lpageDirectory = pd;
    debug.debugPrint("debugPrintPaging:  page directory physical address: 0x{X} virtual address: 0x{X}\n", .{ virtualToPhysical(@intFromPtr(&lpageDirectory)) catch blk: {
        break :blk 0x6969;
    }, @intFromPtr(&lpageDirectory) });
    debug.debugPrint("debugPrintPaging:  kernel start: 0x{X} end: 0x{X}, physical start: 0x{X} end: 0x{X}\n", .{
        @intFromPtr(memory.kernel_start),
        @intFromPtr(memory.kernel_end),
        @intFromPtr(memory.kernel_physical_start),
        @intFromPtr(memory.kernel_physical_end),
    });
    for (lpageDirectory.entries, lpageDirectory.tables, 0..1024) |entery, table, i| {
        if (@as(u32, @bitCast(entery.normal)) == 0) {
            continue;
        }
        for (table.entries, 0..1024) |lPTE, j| {
            if (@as(u32, @bitCast(lPTE)) == 0) {
                continue;
            }
            debug.debugPrint("debugPrintPaging:  directory entry: #{} entry data: 0x{X}\ndebugPrintPaging:  page entry: #{} entry data: 0x{X}, mapped vaddr: 0x{X}\n", .{
                i,
                @as(u32, @bitCast(entery.normal)),
                j,
                @as(u32, @bitCast(lPTE)),
                (i << 22) | (j << 12),
            });
        }
    }
}
