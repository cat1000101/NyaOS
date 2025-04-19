const debug = @import("debug.zig");
const paging = @import("paging.zig");
const multiboot = @import("../../multiboot.zig");
const sched = @import("sched.zig");

pub fn switchToUserMode() void {
    // Set up the stack for user mode.
    const userStack: usize = 0xAFFFF000; // before the start of the kernel by 1 page
    const userStackAddress: usize = 0x800000; // 8MiB
    const userStackMap: usize = 0xAFC00000; // 1GiB - 4MiB
    const programMap: usize = 0x400000; // 4MiB
    const programOffset: usize = 0x50;

    paging.setBigEntryRecursivly(userStackMap, userStackAddress, .{
        .page_size = 1,
        .present = 1,
        .read_write = 1,
        .user_supervisor = 1,
    }) catch |err| {
        debug.printf("userLand.switchToUserMode:  failed to set page table entry: {}\n", .{err});
    };

    const userMainPhysical = multiboot.getModuleEntry(0) orelse {
        debug.printf("userLand.switchToUserMode:  failed to get userLandMain entry\n", .{});
        return;
    };
    const userMainPhysicalAddress: usize = @intFromPtr(userMainPhysical) + programOffset;
    const userMainVirtualAddress: usize = programMap + programOffset; // 4MiB

    paging.setPageTableEntryRecursivly(userMainVirtualAddress, userMainPhysicalAddress, .{
        .present = 1,
        .read_write = 1,
        .user_supervisor = 1,
    }) catch |err| {
        debug.printf("userLand.switchToUserMode:  failed to set page table entry: {}\n", .{err});
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
          [userMain] "{esi}" (userMainVirtualAddress),
    );
    sched.switchContext(&sched.tasks[0]);
}
