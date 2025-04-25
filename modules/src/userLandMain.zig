pub export fn _start() void {
    const string: [*:0]u8 = @ptrCast(@constCast("Hello from userland!\n"));
    asm volatile (
        \\ mov $69, %eax
        \\ int $0x80
        :
        : [string] "{ebx}" (string),
    );
    while (true) {}
}
