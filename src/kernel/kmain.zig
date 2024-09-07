const tty = @import("tty.zig");
const virtio = @import("arch/x86/virtio.zig");
const utils = @import("arch/x86/utils.zig");
const gdt = @import("arch/x86/gdt.zig");
const idt = @import("arch/x86/idt.zig");
const isr = @import("arch/x86/isr.zig");
const pic = @import("arch/x86/pic.zig");

export fn kmain() void {
    virtio.outb("booted?\n");

    tty.initialize();
    tty.printf("meow i like {any} cat femboy", .{69});

    gdt.initGdt();

    idt.initIdt();

    isr.isrInit();

    pic.picRemap(0x20, 0x28);

    asm volatile ("int $1");

    utils.hlt();
}
