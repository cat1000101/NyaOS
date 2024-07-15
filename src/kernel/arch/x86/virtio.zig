pub fn outb(s: []const u8) void {
    for (s) |char| {
        putcharAsm(char);
    }
}

pub fn outNum(num: u32) void {
    asm volatile ("out %[num],$0xe9"
        :
        : [num] "{eax}" (num),
    );
}

fn putcharAsm(c: u8) void {
    asm volatile ("outb %[c],$0xe9"
        :
        : [c] "{al}" (c),
    );
}
