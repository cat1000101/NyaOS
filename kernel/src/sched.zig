const debug = @import("arch/x86/debug.zig");
const paging = @import("arch/x86/paging.zig");
const vmm = @import("mem/vmm.zig");
const kmalloc = @import("mem/kmalloc.zig");
const sched = @import("arch/x86/sched.zig");

pub const schedulerError = error{
    FailedToCreateTask,
    FailedToAllocateStack,
    FailedToAllocatePageDirectory,
};

pub const Context = extern struct {
    pid: usize,
    name: [15:0]u8 = "               ".*,
    stack: *[4096 * 2]u8,
    stackPointer: *u8,
    cr3: *paging.PageDirectory,
};

pub var correntContext: *Context = undefined;
pub var correntPidCount: usize = 0;

pub var tasks: [16]*Context = undefined;

pub fn initSchedler() void {
    _ = createTask("kernel  task   ".*) catch |err| {
        debug.errorPrint("sched.initSchedler:  Failed to create kernel task error:{}\n", .{err});
    };
    sched.saveStateToContext(tasks[0], null);

    debug.infoPrint("Kernel task created with pid: {}\n", .{tasks[0].pid});
}

pub fn createTask(name: [15:0]u8) schedulerError!*Context {
    const allocator = kmalloc.allocator();

    const newTask = allocator.create(Context) catch {
        debug.errorPrint("sched.createTask:  Failed to allocate memory for kernel task\n", .{});
        return schedulerError.FailedToCreateTask;
    };
    newTask.name = name;
    newTask.pid = correntPidCount;
    newTask.stack = @ptrCast(vmm.allocatePages(2) orelse {
        debug.errorPrint("sched.createTask:  Failed to allocate memory for kernel task stack\n", .{});
        return schedulerError.FailedToAllocateStack;
    });
    newTask.stackPointer = &newTask.stack[0x2000 - 1];
    newTask.cr3 = createPageDirectory() orelse {
        debug.errorPrint("sched.createTask:  Failed to allocate memory for page directory\n", .{});
        return schedulerError.FailedToAllocatePageDirectory;
    };

    tasks[correntPidCount] = newTask;
    correntPidCount += 1;

    debug.infoPrint("task created with pid: {}\n", .{newTask.pid});

    return newTask;
}

pub fn createPageDirectory() ?*paging.PageDirectory {
    const newPageDir: *paging.PageDirectory = @ptrCast(@alignCast(vmm.allocatePages(2) orelse {
        debug.errorPrint("sched.createPageDirectory:  failed to allocate pages\n", .{});
        return null;
    }));
    const rootPageDirectory = paging.pageDirectory;

    for (paging.FIRST_KERNEL_DIR_NUMBER..1024) |pageDirIndex| {
        newPageDir.entries[pageDirIndex] = rootPageDirectory.entries[pageDirIndex];
    }
    return newPageDir;
}
