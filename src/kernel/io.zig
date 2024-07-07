pub fn outb(s: []const u8) void {
    for (s) |char| {
        putchar_asm(char);
    }
}

fn putchar_asm(c: u8) void {
    asm volatile ("outb %[c],$0xe9"
        :
        : [c] "{al}" (c),
    );
}
