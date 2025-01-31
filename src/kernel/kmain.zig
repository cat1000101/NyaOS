const tty = @import("drivers/tty.zig");
const virtio = @import("arch/x86/virtio.zig");
const utils = @import("arch/x86/utils.zig");
const gdt = @import("arch/x86/gdt.zig");
const idt = @import("arch/x86/idt.zig");
const acpi = @import("arch/x86/acpi.zig");
const ps2 = @import("arch/x86/ps2.zig");
const multiboot = @import("multiboot.zig");

export fn kmain(mbd: *multiboot.multiboot_info, magic: u32) void {
    _ = multiboot.checkMultibootHeader(mbd, magic);
    virtio.printf("size of pointer:{}\n", .{@sizeOf(*anyopaque)});

    tty.initialize();
    tty.printf("meow i like {any} cats\n", .{69});

    gdt.initGdt();

    idt.initIdt();

    acpi.initACPI();

    ps2.initPs2();

    asm volatile ("int $1"); // test for the interrutps
    // asm volatile ("int $33"); // test for the interrutps

    utils.whileTrue();

    utils.hlt();
}
