const tty = @import("drivers/tty.zig");
const virtio = @import("arch/x86/virtio.zig");
const utils = @import("arch/x86/utils.zig");
const gdt = @import("arch/x86/gdt.zig");
const idt = @import("arch/x86/idt.zig");
const acpi = @import("arch/x86/acpi.zig");
const ps2 = @import("arch/x86/ps2.zig");

export fn kmain() void {
    virtio.printf("booted?\n", .{});
    virtio.printf("size of pointer:{}\n", .{@sizeOf(*anyopaque)});

    tty.initialize();
    tty.printf("meow i like {any} cats\n", .{69});

    gdt.initGdt();

    idt.initIdt();

    const acpiInfo: ?acpi.acpiTables = acpi.initACPI() catch null;
    ps2.initPs2(acpiInfo) catch |err| {
        virtio.printf("ps2 error: {}\n", .{err});
    };

    asm volatile ("int $1"); // test for the interrutps
    asm volatile ("int $33"); // test for the interrutps

    utils.whileTrue();

    utils.hlt();
}
