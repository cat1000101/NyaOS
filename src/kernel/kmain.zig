const tty = @import("tty.zig");

pub fn kmain() void {
    tty.initialize();
    tty.puts("Hello world!");
}
