pub export fn _start() align(16) linksection(".start") callconv(.naked) noreturn {
    asm volatile (
        \\ mov $0xDEADBEEF, %eax
        \\ int $0x80
    );
    while (true) {}
}
