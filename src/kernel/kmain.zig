const tty = @import("tty.zig");
const virtio = @import("arch/x86/virtio.zig");
const utils = @import("arch/x86/utils.zig");
const boot = @import("arch/x86/boot.zig");
const gdt = @import("arch/x86/gdt.zig");
const idt = @import("arch/x86/idt.zig");
const isr = @import("arch/x86/isr.zig");
const pic = @import("arch/x86/pic.zig");
const acpi = @import("arch/x86/acpi.zig");
const ps2 = @import("arch/x86/ps2.zig");

export fn kmain(bootInfo: *boot.bootInfoStruct) void {
    _ = bootInfo; // autofix
    virtio.printf("booted?\n", .{});
    virtio.printf("size of pointer:{}\n", .{@sizeOf(*anyopaque)});

    tty.initialize();
    tty.printf("meow i like {any} cat femboy", .{69});

    gdt.initGdt();

    idt.initIdt();

    isr.isrInit();

    pic.picRemap(0x20, 0x28);

    const acpiInfo: ?acpi.acpiTables = acpi.initACPI() catch |err| blk: {
        virtio.printf("acpi error: {}\n", .{err});
        break :blk null; // TODO: make axpi more pretty and the such
    };
    ps2.init(acpiInfo);

    asm volatile ("int $1");

    utils.hlt();
}
