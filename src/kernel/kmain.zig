const tty = @import("tty.zig");
const virtio = @import("arch/x86/virtio.zig");
const utils = @import("arch/x86/utils.zig");
const gdt = @import("arch/x86/gdt.zig");

export fn kmain() void {
    tty.initialize();
    tty.printf("meow i like {any} cats", .{53});
    virtio.outb("booted?\n");

    gdt.initGdt();

    utils.hlt();
}
