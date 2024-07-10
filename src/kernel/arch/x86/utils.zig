pub fn hlt() void {
    asm volatile ("hlt");
    while (true) asm volatile ("");
}
