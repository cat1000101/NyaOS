const multiboot = @import("multiboot.zig");
const tty = @import("drivers/tty.zig");
const gdt = @import("arch/x86/gdt.zig");
const idt = @import("arch/x86/idt.zig");
const acpi = @import("drivers/acpi.zig");
const ps2 = @import("drivers/ps2.zig");
const pmm = @import("mem/pmm.zig");
const vmm = @import("mem/vmm.zig");
const pit = @import("arch/x86/pit.zig");
const userLand = @import("arch/x86/userLand.zig");
const sched = @import("sched.zig");

const std = @import("std");
const log = std.log;

comptime {
    _ = @import("entry.zig");
}

pub export fn kmain(mbh: *multiboot.multiboot_info, magic: u32) noreturn {
    log.info("size of pointer:{}\n", .{@sizeOf(*anyopaque)});
    _ = multiboot.checkMultibootHeader(mbh, magic);

    gdt.initGdt();

    idt.initIdt();

    pmm.initPmm();

    vmm.initVmm();

    tty.initialize();
    tty.printf("meow i like {any} cats\n", .{69});

    pit.initPit(1193); // 1193 for 1ms~ per tick

    acpi.initACPI();

    ps2.initPs2();

    // sched.initSchedler();
    userLand.switchToUserMode();

    while (true) {
        asm volatile ("");
    }
}

const debug = @import("arch/x86/debug.zig");
pub const panic = @import("panic.zig").panic;
pub const std_options = std.Options{
    .log_level = .info,
    .logFn = debug.myLogFn,
};
