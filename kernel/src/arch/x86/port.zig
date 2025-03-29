// OUT - Send a byte to the specified I/O port
pub inline fn outb(port: u16, data: u8) void {
    asm volatile ("outb %[data], %[port]"
        :
        : [data] "{al}" (data),
          [port] "{dx}" (port),
    );
}

// OUT - Send a word to the specified I/O port
pub inline fn outw(port: u16, data: u16) void {
    asm volatile ("outw %[data], %[port]"
        :
        : [data] "{ax}" (data),
          [port] "{dx}" (port),
    );
}

// OUT - Send a double word to the specified I/O port
pub inline fn outl(port: u16, data: u32) void {
    asm volatile ("outl %[data], %[port]"
        :
        : [data] "{eax}" (data),
          [port] "{dx}" (port),
    );
}

// IN - Read a byte from the specified I/O port
pub inline fn inb(port: u16) u8 {
    var ret: u8 = 0;
    asm volatile ("inb %[port], %[ret]"
        : [ret] "=r" (ret),
        : [port] "{dx}" (port),
    );
    return ret;
}

// IN - Read a word from the specified I/O port
pub inline fn inw(port: u16) u16 {
    var ret: u16 = 0;
    asm volatile ("inw %[port], %[ret]"
        : [ret] "=r" (ret),
        : [port] "{dx}" (port),
    );
    return ret;
}

// IN - Read a double word from the specified I/O port
pub inline fn inl(port: u16) u32 {
    var ret: u32 = 0;
    asm volatile ("inl %[port], %[ret]"
        : [ret] "=r" (ret),
        : [port] "{dx}" (port),
    );
    return ret;
}

// INS - Input string (byte) from port into memory
pub inline fn insb(port: u16, addr: *void, count: u32) void {
    asm volatile ("rep insb"
        : [addr] "+{edi}" (addr),
          [count] "+{ecx}" (count),
        : [port] "{dx}" (port),
        : "memory"
    );
}

// INS - Input string (word) from port into memory
pub inline fn insw(port: u16, addr: *void, count: u32) void {
    asm volatile ("rep insw"
        : [addr] "+{edi}" (addr),
          [count] "+{ecx}" (count),
        : [port] "{dx}" (port),
        : "memory"
    );
}

// INS - Input string (double word) from port into memory
pub inline fn insd(port: u16, addr: *void, count: u32) void {
    asm volatile ("rep insd"
        : [addr] "+{edi}" (addr),
          [count] "+{ecx}" (count),
        : [port] "{dx}" (port),
        : "memory"
    );
}

// OUTS - Output string (byte) from memory to port
pub inline fn outsb(port: u16, addr: *const void, count: u32) void {
    asm volatile ("rep outsb"
        : [addr] "+{esi}" (addr),
          [count] "+{ecx}" (count),
        : [port] "{dx}" (port),
    );
}

// OUTS - Output string (word) from memory to port
pub inline fn outsw(port: u16, addr: *const void, count: u32) void {
    asm volatile ("rep outsw"
        : [addr] "+{esi}" (addr),
          [count] "+{ecx}" (count),
        : [port] "{dx}" (port),
    );
}

// OUTS - Output string (double word) from memory to port
pub inline fn outsd(port: u16, addr: *const void, count: u32) void {
    asm volatile ("rep outsd"
        : [addr] "+{esi}" (addr),
          [count] "+{ecx}" (count),
        : [port] "{dx}" (port),
    );
}

pub inline fn io_wait() void {
    outb(0x80, 0);
}
