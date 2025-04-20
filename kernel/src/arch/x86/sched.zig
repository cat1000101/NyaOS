const sched = @import("../../sched.zig");
const paging = @import("paging.zig");
const gdt = @import("gdt.zig");
const main = @import("../../main.zig");

pub fn switchContext(newContext: *sched.Context) void {
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
        : [old_sp] "+{esi}" (&sched.correntContext.stackPointer),
          [new_sp] "{edi}" (newContext.stackPointer),
    );
}

/// idk need to learn what to do here
/// intended to be used when doing a iret to userland or something
/// the ret address and args need to be refrenced to function that uses the stack for the args (export?)
pub fn saveContext(context: *sched.Context, retAddress: ?*const u8, retArgs: ?*anyopaque) void {
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
