const tty = @import("drivers/tty.zig");
const debug = @import("arch/x86/debug.zig");
const utils = @import("arch/x86/utils.zig");
const gdt = @import("arch/x86/gdt.zig");
const idt = @import("arch/x86/idt.zig");
const acpi = @import("drivers/acpi.zig");
const ps2 = @import("drivers/ps2.zig");
const multiboot = @import("multiboot.zig");
const pmm = @import("mem/pmm.zig");
const vmm = @import("mem/vmm.zig");

const panic = @import("panic.zig");

pub export fn kmain(mbh: *multiboot.multiboot_info, magic: u32) void {
    debug.printf("size of pointer:{}\n", .{@sizeOf(*anyopaque)});
    _ = multiboot.checkMultibootHeader(mbh, magic);

    gdt.initGdt();

    idt.initIdt();

    pmm.initPmm();

    vmm.initVmm();

    tty.initialize();
    tty.printf("meow i like {any} cats\n", .{69});

    acpi.initACPI();

    ps2.initPs2();

    utils.whileTrue();

    utils.hlt();
}
