const debug = @import("debug.zig");
const memory = @import("../../mem/memory.zig");
const paging = @import("paging.zig");
const vmm = @import("../../mem/vmm.zig");
const kmalloc = @import("../../mem/kmalloc.zig");
const gdt = @import("gdt.zig");
const main = @import("../../main.zig");

pub const kernelThreadStackSize = memory.PAGE_SIZE * 2; // 8KB

pub const schedulerError = error{
    FailedToCreateTask,
    FailedToAllocateStack,
};

pub const Context = extern struct {
    pid: usize,
    name: [15:0]u8 = "               ".*,
    stack: *u8,
    stackPointer: *u8,
    cr3: *paging.PageDirectory,
};

pub var correntContext: *Context = undefined;
pub var correntPidCount: usize = 0;

pub var tasks: [16]*Context = undefined;

pub fn initSchedler() void {
    _ = createTask("kernel  task   ".*, paging.getCr3()) catch |err| {
        debug.printf("sched.initSchedler:  Failed to create kernel task error:{}\n", .{err});
    };
    saveContext(tasks[0], null, null);

    debug.printf("Kernel task created with pid: {}\n", .{tasks[0].pid});
}

pub fn createTask(name: [15:0]u8, cr3: *paging.PageDirectory) schedulerError!*Context {
    const allocator = kmalloc.allocator();

    const newTask = allocator.create(Context) catch {
        debug.printf("sched.createTask:  Failed to allocate memory for kernel task\n", .{});
        return schedulerError.FailedToCreateTask;
    };
    newTask.name = name;
    newTask.pid = correntPidCount;
    newTask.stack = @ptrCast(vmm.allocatePages(2) orelse {
        debug.printf("sched.createTask:  Failed to allocate memory for kernel task stack\n", .{});
        return schedulerError.FailedToAllocateStack;
    });
    newTask.stackPointer = newTask.stack;
    newTask.cr3 = cr3;

    tasks[correntPidCount] = newTask;
    correntPidCount += 1;

    debug.printf("sched.createTask:  task created with pid: {}\n", .{newTask.pid});

    return newTask;
}

pub fn switchContext(newContext: *Context) void {
    gdt.updateTss(@intFromPtr(newContext.stack));
    gdt.loadTss();

    paging.setCr3(newContext.cr3);
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
        : [old_sp] "+{esi}" (&correntContext.stackPointer),
          [new_sp] "{edi}" (newContext.stackPointer),
    );
}

/// idk need to learn what to do here
/// intended to be used when doing a iret to userland or something
/// the ret address and args need to be refrenced to function that uses the stack for the args (export?)
pub fn saveContext(context: *Context, retAddress: ?*const u8, retArgs: ?*anyopaque) void {
    const lretAddress = retAddress orelse @as(*const u8, @ptrFromInt(@returnAddress()));
    asm volatile (
        \\  movl %esp, %esi // save corrent stack
        \\  movl %[contextStack], %esp
        \\
        \\  cmpl %[retArgs], 0
        \\  je no_args
        \\  pushl %[retArgs] // need to check call conventrion
        \\  no_args:
        \\
        \\  pushl %[retAddress]
        \\
        \\  pushl %[contextStack] // ebp will also be the start of the stack
        :
        : [contextStack] "{eax}" (context.stack),
          [retAddress] "{edi}" (lretAddress),
          [retArgs] "{ecx}" (retArgs),
        : "{esp}", "{esi}"
    );

    asm volatile (
        \\  push %edi // emulate what switchContextMiddle does (register save)
        \\  push %esi // emulate what switchContextMiddle does (register save)
        \\  sub $0x14, %esp // switchContext call stack size(the stack viratbles)
        \\  pusha
        \\  
        \\  movl %esp, (%[old_sp])
        \\
        \\  movl %esi, %esp // restore the corrent context stack
        :
        : [old_sp] "+{edx}" (&context.stackPointer),
        : "{esp}", "{esi}"
    );
}
