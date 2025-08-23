const sched = @import("../../sched.zig");
const paging = @import("paging.zig");
const gdt = @import("gdt.zig");
const bootEntry = @import("../../entry.zig");

pub fn switchContext(oldContext: *sched.Context, newContext: *sched.Context) void {
    gdt.updateTss(@intFromPtr(newContext.stack));
    gdt.loadTss();

    paging.setCr3(newContext.cr3);
    switchThread(&oldContext.stackPointer, newContext.stackPointer);
}

pub export fn switchThread(oldStack: **u8, newStack: *u8) void {
    asm volatile (
        \\  .global switchThreadMiddle;
        \\  pusha
        \\  
        \\  movl %esp, (%[old_sp])
        \\  switchThreadMiddle:
        \\  movl %[new_sp], %esp
        \\
        \\  popa
        :
        : [old_sp] "+{esi}" (oldStack),
          [new_sp] "{edi}" (newStack),
        : .{ .esp = true }
    );
}

/// idk need to learn what to do here
/// intended to be used when doing a iret to userland or something
/// the ret address and args need to be refrenced to function that uses the stack for the args (export?)
pub export fn saveStateToContext(context: *sched.Context, retAddress: ?*const u8) void {
    asm volatile (
        \\  movl %esp, %esi // save corrent stack
        \\  movl %[contextStack], %esp
        \\
        \\  pushl %[retAddress]
        \\
        \\  pushl %[contextStack] // ebp will also be the start of the stack
        \\
        \\  push %edi // emulate what switchContextMiddle does (register save)
        \\  push %esi // emulate what switchContextMiddle does (register save)
        \\  pusha
        \\  
        \\  movl %esp, (%[old_sp])
        \\
        \\  movl %esi, %esp // restore the corrent context stack
        :
        : [old_sp] "+{ecx}" (&context.stackPointer),
          [contextStack] "{edx}" (context.stack),
          [retAddress] "{edi}" (retAddress),
        : .{ .esp = true, .esi = true }
    );
}
