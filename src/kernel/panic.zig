const virtio = @import("arch/x86/virtio.zig");
const tty = @import("drivers/tty.zig");
const utils = @import("arch/x86/utils.zig");

pub fn panic(msg: []const u8, first_trace_addr: ?usize) noreturn {
    _ = first_trace_addr;
    tty.printf("PANIC: {}\n", .{msg});
    virtio.printf("PANIC: {}\n", .{msg});
    utils.whileTrue();
}
