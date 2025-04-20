const debug = @import("arch/x86/debug.zig");
const paging = @import("arch/x86/paging.zig");
const vmm = @import("mem/vmm.zig");
const kmalloc = @import("mem/kmalloc.zig");
const sched = @import("arch/x86/sched.zig");

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
    sched.saveContext(tasks[0], null, null);

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
