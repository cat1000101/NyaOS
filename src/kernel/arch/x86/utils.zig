pub fn hlt() void {
    asm volatile ("hlt");
    while (true) asm volatile ("");
}

pub fn whileTrue() void {
    while (true) asm volatile ("");
}
