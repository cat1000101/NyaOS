const tty = @import("tty.zig");
const virtio = @import("arch/x86/virtio.zig");
const utils = @import("arch/x86/utils.zig");
const gdt = @import("arch/x86/gdt.zig");
const idt = @import("arch/x86/idt.zig");

export fn kmain() void {
    virtio.outb("booted?\n");

    tty.initialize();
    tty.printf("meow i like {any} cats", .{53});

    gdt.initGdt();

    idt.initIdt();

    utils.hlt();
}
