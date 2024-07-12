const std = @import("std");
const virtio = @import("virtio.zig");

pub const GdtEntry = packed struct {
    limit_low: u16,
    base_low: u24,
    access: Access,
    limit_high: u4,
    flags: Flags,
    base_high: u8,
};

pub const Tss = packed struct {
    link: u16,
    Reserved1: u16,
    esp0: u32,
    ss0: u16,
    Reserved2: u16,
    esp1: u32,
    ss1: u16,
    Reserved3: u16,
    esp2: u32,
    ss2: u16,
    Reserved4: u16,
    cr3: u32,
    EIP: u32,
    EFLAGS: u32,
    EAX: u32,
    ECX: u32,
    EDX: u32,
    EBX: u32,
    ESP: u32,
    EBP: u32,
    ESI: u32,
    EDI: u32,
    es: u16,
    preserved6: u16,
    cs: u16,
    preserved7: u16,
    ss: u16,
    preserved8: u16,
    ds: u16,
    preserved9: u16,
    fs: u16,
    preserved10: u16,
    gs: u16,
    preserved11: u16,
    ldtr: u16,
    preserved12: u32,
    iopb: u16,
    ssp: u32,
};

pub const GdtPtr = packed struct {
    limit: u16,
    base: u32,
};

pub const Flags = packed struct {
    preserved: u1 = 0,
    l: u1, //L: Long-mode code flag. If set (1), the descriptor defines a 64-bit code segment. When set, DB should always be clear. For any other type of segment (other code types or any data segment), it should be clear (0).
    db: u1, //DB: Size flag. If clear (0), the descriptor defines a 16-bit protected mode segment. If set (1) it defines a 32-bit protected mode segment. A GDT can have both 16-bit and 32-bit selectors at once.
    g: u1, //G: Granularity flag, indicates the size the Limit value is scaled by. If clear (0), the Limit is in 1 Byte blocks (byte granularity). If set (1), the Limit is in 4 KiB blocks (page granularity).
};

pub const Access = packed struct {
    a: u1, //A: Accessed bit. The CPU will set it when the segment is accessed unless set to 1 in advance.
    rw: u1, //RW: Readable bit/Writable bit.
    dc: u1, //DC: Direction bit/Conforming bit. when data sector : 0 for up 1 for down when code sector : 0 execute from the same ring 1 for jumping to higher place.
    e: u1, //E: Executable bit. If clear (0) the descriptor defines a data segment. If set (1) it defines a code segment which can be executed from.
    s: u1, //S: Descriptor type bit. If clear (0) the descriptor defines a system segment (eg. a Task State Segment). If set (1) it defines a code or data segment.
    dpl: u2, //DPL: Descriptor privilege level field. Contains the CPU Privilege level of the segment. 0 = highest privilege (kernel), 3 = lowest privilege (user applications).
    p: u1, //P: Present bit. Allows an entry to refer to a valid segment. Must be set (1) for any valid segment.
};

const NULL_ACCESS: Access = std.mem.zeroes(Access);
const NULL_FLAGS: Flags = std.mem.zeroes(Flags);

const BIT32_PAGED_FLAGS: Flags = .{ .g = 1, .db = 1, .l = 0, .preserved = 0 };
const TASK_STATE: Flags = .{ .g = 1, .db = 0, .l = 0, .preserved = 0 };

const KERNEL_CODE_ACCESS: Access = .{ .p = 1, .dpl = 0, .s = 1, .e = 1, .dc = 0, .rw = 1, .a = 0 };
const KERNEL_DATA_ACCESS: Access = .{ .p = 1, .dpl = 0, .s = 1, .e = 0, .dc = 0, .rw = 1, .a = 0 };
const USER_CODE_ACCESS: Access = .{ .p = 1, .dpl = 3, .s = 1, .e = 1, .dc = 0, .rw = 1, .a = 0 };
const USER_DATA_ACCESS: Access = .{ .p = 1, .dpl = 3, .s = 1, .e = 0, .dc = 0, .rw = 1, .a = 0 };
const TASK_STATE_ACCESS: Access = .{ .p = 1, .dpl = 0, .s = 0, .e = 1, .dc = 0, .rw = 0, .a = 1 };

const NUMBER_OF_ENTRIES: u16 = 0x06;

var gdt_entries: [NUMBER_OF_ENTRIES]GdtEntry = undefined;
var tss_entry: Tss = std.mem.zeroes(Tss);
var gdt_ptr: GdtPtr = undefined;

pub fn initGdt() void {
    gdt_ptr.limit = (@sizeOf(GdtEntry) * NUMBER_OF_ENTRIES) - 1;
    gdt_ptr.base = @intFromPtr(&gdt_entries);
    setTssTable(&tss_entry, 0x10, @sizeOf(Tss));

    setGdtGate(
        0,
        0,
        0,
        NULL_ACCESS,
        NULL_FLAGS,
    );
    setGdtGate(
        1,
        0,
        0xFFFFF,
        KERNEL_CODE_ACCESS,
        BIT32_PAGED_FLAGS,
    ); // kernel code segment
    setGdtGate(
        2,
        0,
        0xFFFFF,
        KERNEL_DATA_ACCESS,
        BIT32_PAGED_FLAGS,
    ); // kernel data segment
    setGdtGate(
        3,
        0,
        0xFFFFF,
        USER_CODE_ACCESS,
        BIT32_PAGED_FLAGS,
    ); // user code segment
    setGdtGate(
        4,
        0,
        0xFFFFF,
        USER_DATA_ACCESS,
        BIT32_PAGED_FLAGS,
    ); // user data segment
    setGdtGate(
        5,
        @intFromPtr(&tss_entry),
        @sizeOf(Tss),
        TASK_STATE_ACCESS,
        TASK_STATE,
    ); // Task State Segment

    gdtFlush(&gdt_ptr);
    virtio.outb("initialized gdt\n");

    loadTss();
    virtio.outb("initialized Tss\n");
}
fn setGdtGate(num: u32, base: u32, limit: u20, access: Access, flags: Flags) void {
    gdt_entries[num].base_low = @truncate(base);
    gdt_entries[num].base_high = @truncate(base >> 24);
    gdt_entries[num].limit_low = @truncate(limit);
    gdt_entries[num].limit_high = @truncate(limit >> 16);
    gdt_entries[num].flags = flags;
    gdt_entries[num].access = access;
}

fn setTssTable(tss: *Tss, ss0: u16, iopb: u16) void {
    tss.ss0 = ss0;
    tss.iopb = iopb;
}

fn gdtFlush(gdt_ptr_: *GdtPtr) void {
    // Load the GDT into the CPU
    asm volatile ("lgdt (%%eax)"
        :
        : [gdt_ptr_] "{eax}" (gdt_ptr_),
        : "%eax"
    );

    // Load the kernel data segment, index into the GDT
    asm volatile ("mov $0x10, %%bx" ::: "%bx");
    asm volatile ("mov %%bx, %%ds" ::: "%ds");
    asm volatile ("mov %%bx, %%es" ::: "%es");
    asm volatile ("mov %%bx, %%fs" ::: "%fs");
    asm volatile ("mov %%bx, %%gs" ::: "%gs");
    asm volatile ("mov %%bx, %%ss" ::: "%ss");

    // Load the kernel code segment into the CS register
    asm volatile (
        \\ljmp $0x08, $1f
        \\1:
    );
}

fn loadTss() void {
    // Load the Tss into the CPU
    asm volatile (
        \\ movw $0x28 , %%ax
        \\ ltr %%ax
        ::: "%ax");
}
