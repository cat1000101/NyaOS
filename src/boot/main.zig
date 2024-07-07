const kmain = @import("kmain.zig");

const ALIGN = 1 << 0;
const MEMINFO = 1 << 1;
const MAGIC = 0x1BADB002;
const FLAGS = ALIGN | MEMINFO;

const MultibootHeader = extern struct {
    magic: i32 = MAGIC,
    flags: i32 align(1),
    checksum: i32 align(1),
};

export var multiboot align(4) linksection(".multiboot") = MultibootHeader{
    .flags = FLAGS,
    .checksum = -(MAGIC + FLAGS),
};

export var stack_bytes: [16 * 1024]u8 align(16) linksection(".bss") = undefined;
const stack_bytes_slice = stack_bytes[0..];

export fn _start() callconv(.Naked) noreturn {
    @call(.auto, kmain.kmain, .{});

    while (true) {}
}
