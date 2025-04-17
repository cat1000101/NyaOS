const debug = @import("debug.zig");
const paging = @import("paging.zig");

pub fn switchToUserMode() void {

    // Set up the stack for user mode.
    const userStack: usize = 0xBFFFF000; // before the start of the kernel by 1 page
    const userStackAddress: usize = 0xC00000; // 12MiB
    const userStackMap: usize = 0xBFC00000; // 1GiB - 4MiB
    const userProgramAddress: usize = 0x800000; // 8MiB
    const userProgramMap: usize = 0x1400000; // 20MiB

    paging.setBigEntryRecursivly(userStackMap, userStackAddress, .{
        .page_size = 1,
        .present = 1,
        .read_write = 1,
        .user_supervisor = 1,
    }) catch |err| {
        debug.printf("userLand.switchToUserMode:  failed to set page table entry: {}\n", .{err});
    };
    paging.setBigEntryRecursivly(userProgramMap, userProgramAddress, .{
        .page_size = 1,
        .present = 1,
        .read_write = 1,
        .user_supervisor = 1,
    }) catch |err| {
        debug.printf("userLand.switchToUserMode:  failed to set page table entry: {}\n", .{err});
    };

    debug.printf("size of function: 0x{x} at: {*}\n", .{ 0, &userLandMain });

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
        \\ pushl %[stackStart]    // ESP
        \\
        \\ pushf
        \\ pop %eax
        \\ or $0x200, %eax
        \\ push %eax              // EFLAGS
        \\
        \\ pushl $0x1B            // CS
        \\ push %[userLandMain]   // EIP
        \\ iret
        :
        : [stackStart] "{edx}" (userStack),
          [userLandMain] "{esi}" (&userLandMain),
    );
}

pub export fn userLandMain() void {
    debug.printf("userLandMain:  Hello from user land!\n", .{});
    while (true) {
        asm volatile ("hlt");
    }
}
