const debug = @import("debug.zig");
const paging = @import("paging.zig");
const vmm = @import("../../mem/vmm.zig");
const memory = @import("../../mem/memory.zig");
const multiboot = @import("../../multiboot.zig");
const sched = @import("sched.zig");
const highSched = @import("../../sched.zig");
const elf = @import("../../drivers/elf.zig");

pub fn switchToUserMode() void {
    // Set up the stack for user mode.
    const userStack: usize = 0xAFFFF000; // 2.75GiB - 4KiB virtual
    const userStackBottom: usize = 0xAFC00000; // 2.75GiB - 4MiB virtual
    const userStackAddress: usize = 0x2000000; // 32MiB physical
    const elfFileMap: usize = 0x10000000; // 256MiB virtual
    const programRandomHeap: usize = 0xA0000000; // 2.5GiB virtual

    paging.setBigEntryRecursivly(userStackBottom, userStackAddress, .{
        .page_size = 1,
        .present = 1,
        .read_write = 1,
        .user_supervisor = 1,
    }) catch |err| {
        debug.errorPrint("userLand.switchToUserMode:  failed to set page table entry: {}\n", .{err});
    };

    const moudleList = multiboot.getModuleInfo() orelse {
        debug.errorPrint("userLand.switchToUserMode:  failed to get module list\n", .{});
        return;
    };
    const physcialAddress: u32 = moudleList[0].mod_start;
    const length: u32 = moudleList[0].mod_end - moudleList[0].mod_start;
    debug.infoPrint("elf file physical location: 0x{X} length: 0x{X}\n", .{ physcialAddress, length });

    paging.idPagesRecursivly(elfFileMap, physcialAddress, memory.alignAddressUp(length, memory.PAGE_SIZE), true) catch {
        debug.errorPrint("userLand.switchToUserMode:  failed to id map virtual address range\n", .{});
        return;
    };

    const fileManyPointer: [*]u8 = @ptrFromInt(elfFileMap);
    const fileSlice: []u8 = fileManyPointer[0..length];

    const programMemory = elf.loadFile(fileSlice) catch |err| {
        debug.errorPrint("userLand.switchToUserMode:  failed to load elf: {}\n", .{err});
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
