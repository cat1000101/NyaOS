pub export fn _start() void {
    asm volatile (
        \\ mov $0xDEADBEEF, %eax
        \\ int $0x80
    );
    while (true) {}
}
