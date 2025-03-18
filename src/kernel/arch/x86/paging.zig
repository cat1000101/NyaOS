const virtio = @import("virtio.zig");

const std = @import("std");

pub const PageDirectoryEntery = packed struct {
    flags: PageDirectoryEnteryFlags = .{},
    MINE: u1 = 0, // i do whatever i want to store data or something
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
    MINE: u3 = 0,
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

extern const kernel_start: u32;
extern const kernel_physical_start: u32;
pub const firstHigherHalfPageNumber: u32 = 768;

pub const PageTable = [1024]PageTableEntery;
pub const PageDirectory = [1024]PageDirectoryEntery;

pub export var pageDirectory: PageDirectory align(4096) = [_]PageDirectoryEntery{.{}} ** 1024;
pub export var higherHalfPage: PageTable align(4096) = [_]PageTableEntery{.{}} ** 1024;
pub export var firstPage: PageTable align(4096) = [_]PageTableEntery{.{}} ** 1024;

// comptime {
//     setPageDirectoryEntery(0, @intFromPtr(&firstPage), .{ .present = 1, .read_write = 1 });
//     idPaging(&firstPage, 0, 0x100000);
//     setPageDirectoryEntery(firstHigherHalfPageNumber, @intFromPtr(&higherHalfPage), .{ .present = 1, .read_write = 1 });
//     mapHigherHalf(&pageDirectory);
// }

pub fn setPage(page: *PageTable, index: u32, address: u32, flags: PageTableEnteryFlags) void {
    page[index] = PageTableEntery{
        .flags = flags,
        .address = @truncate(address >> 12),
    };
}

pub fn setPageDirectoryEntery(index: u32, address: u32, flags: PageDirectoryEnteryFlags) void {
    pageDirectory[index] = PageDirectoryEntery{
        .flags = flags,
        .address = @truncate(address >> 12),
    };
}

pub fn setPageDirectoryEnteryBig(index: u32, address: u32, flags: PageDirectoryEnteryFlagsBig) void {
    pageDirectory[index] = PageDirectoryEnteryBig{
        .flags = flags,
        .address_low = @truncate(address >> 12),
        .address_high = @truncate(address >> 32),
    };
}

fn idPaging(pt: *PageTable, vaddr: u32, size: u32) void {
    var pageIdentety: u32 = vaddr & 0xfffff000;
    var index = vaddr >> 12 & 0x3ff;
    var memoryLeftToMap = size;
    while (memoryLeftToMap > 0 and index < 1024) : ({
        pageIdentety += 0x1000;
        index += 1;
        memoryLeftToMap -= 0x1000;
    }) {
        pt[index] = @bitCast(pageIdentety | 0b11);
    }
}

fn mapHigherHalf(pd: *PageDirectory) void {
    var physicalAddress: u32 = @intFromPtr(&kernel_physical_start) & 0xfffff000;
    var index = 0;
    const page: *PageTable = @ptrFromInt(@as(u32, pd[firstHigherHalfPageNumber].address) << 12);
    while (index < 1024) : ({
        physicalAddress += 0x1000;
        index += 1;
    }) {
        page[index] = @bitCast(physicalAddress | 0b11);
    }
}
