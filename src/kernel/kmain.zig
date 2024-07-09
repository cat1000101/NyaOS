const tty = @import("tty.zig");
const virtio = @import("virtio.zig");
const utils = @import("utils.zig");

export fn kmain() void {
    tty.initialize();
    tty.printf("meow i like {any} cats", .{53});
    virtio.outb("meow?");
    utils.hlt();
}
