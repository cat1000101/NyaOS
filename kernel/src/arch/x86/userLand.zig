const debug = @import("debug.zig");

pub fn switchToUserMode() void {

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
        \\ mov %esp, %eax
        \\ pushl $0x23        // SS
        \\ pushl %eax         // ESP
        \\
        \\ pushf
        \\ pop %eax
        \\ or $0x200, %eax
        \\ push %eax          // EFLAGS
        \\
        \\ pushl $0x1B        // CS
        \\ push $1f           // EIP
        \\ iret
    );
}
