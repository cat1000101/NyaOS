const tty = @import("tty.zig");
const io_qemu = @import("io.zig");

export fn kmain() void {
    io_qemu.outb("meow?");
    tty.initialize();
    tty.puts("Hello world!");
    asm volatile ("hlt");
    while (true) asm volatile ("");
}
