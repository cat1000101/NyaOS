const paging = @import("paging.zig");
const files = @import("../../mem/files.zig");
const elf = @import("../../drivers/elf.zig");
const sched = @import("sched.zig");
const highSched = @import("../../sched.zig");
const debug = @import("debug.zig");

const log = @import("std").log;

pub const userStack: usize = 0xAFFFF000; // 2.75GiB - 4KiB virtual
pub const userStackBottom: usize = 0xAFC00000; // 2.75GiB - 4MiB virtual
pub const userStackAddress: usize = 0x2000000; // 32MiB physical
pub var fileMaps: usize = 0x10000000; // 256MiB virtual
pub const programRandomHeap: usize = 0x8000000; // 128MiB virtual

pub fn switchToUserMode() void {
    if (true) {
        @panic("test");
    }

    // Set up the stack for user mode.
    paging.setBigEntryRecursivly(userStackBottom, userStackAddress, .{
        .page_size = 1,
        .present = 1,
        .read_write = 1,
        .user_supervisor = 1,
    }) catch |err| {
        log.err("userLand.switchToUserMode:  failed to set page table entry: {}\n", .{err});
    };

    const file = files.open("doomgeneric.elf", 0) catch |err| {
        log.err("userLand.switchToUserMode:  failed to open userLand program: {}\n", .{err});
        return;
    };
    const fileSlice = file.file;

    const programMemory = elf.loadFile(fileSlice) catch |err| {
        log.err("userLand.switchToUserMode:  failed to load elf: {}\n", .{err});
        return;
    };
    const programEntry = elf.getEntryPoint(fileSlice);
    threadData = .{
        .threadEntry = @intFromPtr(programEntry),
        .threadBreak = programMemory.len + @intFromPtr(programMemory.ptr),
        .threadRandomHeap = programRandomHeap,
    };

    // Set up a stack structure for switching to user mode.
    // 0x23 is the data segment with user privileges.
    // 0x1B is the code segment with user privileges.
    // 0x200 is the IF flag in EFLAGS register, which enables interrupts.
    debug.bochsBreak();
    asm volatile (
        \\ cli
        \\ mov $0x23, %ax
        \\ mov %ax, %ds
        \\ mov %ax, %es
        \\ mov %ax, %fs
        \\ mov %ax, %gs
        \\         
        \\ pushl $0x23            // SS
        \\ pushl %[userStack]    // ESP
        \\
        \\ pushf
        \\ pop %eax
        \\ or $0x200, %eax
        \\ push %eax              // EFLAGS
        \\
        \\ pushl $0x1B            // CS
        \\ push %[userMain]   // EIP
        \\ iret
        :
        : [userStack] "{edx}" (userStack),
          [userMain] "{esi}" (programEntry),
    );
    sched.switchContext(highSched.correntContext, highSched.correntContext);
}

pub const ThreadContext = struct {
    threadEntry: u32,
    threadBreak: u32,
    threadRandomHeap: u32,
};
pub var threadData: ThreadContext = undefined;
