const debug = @import("debug.zig");
const memory = @import("../../mem/memory.zig");
const paging = @import("paging.zig");
const kmalloc = @import("../../mem/kmalloc.zig");
const gdt = @import("gdt.zig");
const main = @import("../../main.zig");

pub const kernelThreadStackSize = memory.PAGE_SIZE * 2; // 8KB

pub const Context = extern struct {
    pid: usize,
    name: [15:0]u8 = "               ".*,
    stack: *u8,
    stackPointer: *u8,
    cr3: *paging.PageDirectory,
};

pub var correntContext: *Context = undefined;
pub var correntPidCount: usize = 0;

pub var tasks: []Context = undefined;

pub fn initSchedler() void {
    const allocator = kmalloc.allocator();

    tasks = allocator.alloc(Context, 1) catch {
        debug.printf("sched.initSchedler:  Failed to allocate memory for kernel task\n", .{});
        return;
    };
    tasks[0] = Context{
        .pid = 0,
        .name = "kernel  task   ".*,
        .stack = main.stack_top,
        .stackPointer = main.stack_top,
        .cr3 = paging.getCr3(),
    };
    correntPidCount += 1;

    debug.printf("Kernel task created with pid: {}\n", .{tasks[0].pid});
}

pub fn switchContext(newContext: *Context) void {
    gdt.updateTss(@intFromPtr(newContext.stack));
    gdt.loadTss();

    paging.setCr3(newContext.cr3);
    const oldStackPointer: **u8 = &correntContext.stackPointer;
    asm volatile (
        \\  .global switchContextMiddle;
        \\  pusha
        \\  
        \\  movl %esp, (%[old_sp])
        \\  switchContextMiddle:
        \\  movl %[new_sp], %esp
        \\
        \\  popa
        :
        : [old_sp] "+{esi}" (oldStackPointer),
          [new_sp] "{edi}" (newContext.stackPointer),
    );
}

/// idk need to learn what to do here
pub fn saveContext(context: *Context, retAddress: *u8, cs: u32, ss: u32, eflags: u32, userStack: u32) void {
    asm volatile (
        \\  movl %[contextStack], %esp
        \\  pushl %[ss]
        \\  pushl %[userStack]
        \\  pushl %[eflags]
        \\  pushl %[cs]
        \\  pushl %[retAddress]
        \\
        \\  sub %esp, $0x14 // switchContext call stack size(the thing that were pushed by calling switchContext)
        \\  pusha
        \\  
        \\  movl %esp, %[old_sp]
        :
        : [contextStack] "{eax}" (context.stack),
          [cs] "{ebx}" (cs),
          [ss] "{ecx}" (ss),
          [eflags] "{edx}" (eflags),
          [userStack] "{esi}" (userStack),
          [retAddress] "{edi}" (retAddress),
    );
}
// \\ pushl $0x23            // SS
// \\ pushl %[userStack]    // ESP
// \\ push %eax              // EFLAGS
// \\
// \\ pushl $0x1B            // CS
// \\ push %[userMain]   // EIP
