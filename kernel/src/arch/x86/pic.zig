const port = @import("port.zig");
const debug = @import("debug.zig");
const idt = @import("idt.zig");
const utils = @import("utils.zig");

pub const PIC_MASTER_OFFSET: u16 = 0x20;
pub const PIC_SLAVE_OFFSET: u16 = 0x28;

const PIC_MASTER = 0x20; // the base io offset of the pic master chip
const PIC_SLAVE = 0xA0; // the base io offset of the pic slave chip
const PIC_MASTER_COMMAND = PIC_MASTER; // the port where the master accepts commands
const PIC_MASTER_DATA = PIC_MASTER + 1; // the port where the master outputs data
const PIC_SLAVE_COMMAND = PIC_SLAVE; // the port where the slave accepts commands
const PIC_SLAVE_DATA = PIC_SLAVE + 1; // the port where the slave outputs data

const PIC_EOI = 0x20; // code of end interrupt

const ICW1_ICW4 = 0x01; // tells the pic that ICW4 is reqiered(1) and (0) for the opisite
const ICW1_SINGLE = 0x02; // (1) there is only 1 pic (0) there are multiple pic
const ICW1_INTERVAL4 = 0x04; // (1) interrupt vector is spaced by 4 bytes (0) 8 bytes spacing
const ICW1_LEVEL = 0x08; // (1) for level-triggered mode (for interrupts that remain active until explicitly acknowledged) (0) for edge-triggered mode
const ICW1_INIT = 0x10; // init bit must be 1 for the initialization process

const ICW4_8086 = 0x01; // tells the pic to use 8086/88(set to 1) mode instead of MCS-80/85(set to 0)
const ICW4_AUTO = 0x02; // (1) Auto End of Interrupt (EOI) mode (0) manually send EOI
const ICW4_BUF_SLAVE = 0x08; // (1) PIC is operating in buffered mode as a slave device
const ICW4_BUF_MASTER = 0x0C; // (1) PIC is operating in buffered mode as a master device
const ICW4_SFNM = 0x10; // (1) enable special fully nested mode for cascading PICs (used when you have more than one PIC).

/// sends to the pic that interrupt has ended
pub fn picSendEOI(irq: u8) void {
    if (irq >= 8)
        port.outb(PIC_SLAVE_COMMAND, PIC_EOI);

    port.outb(PIC_MASTER_COMMAND, PIC_EOI);
}

/// disables the pic
pub fn picDisable() void {
    port.outb(PIC_MASTER_DATA, 0xff);
    port.outb(PIC_SLAVE_DATA, 0xff);
}

/// remaps the pic offsets, recommanded for master 0x20 and for the slave 0x28
fn picRemap(offsetMaster: u8, offsetSlave: u8) void {
    port.outb(PIC_MASTER_COMMAND, ICW1_INIT | ICW1_ICW4); // starts the initialization sequence (in cascade mode)
    port.io_wait();
    port.outb(PIC_SLAVE_COMMAND, ICW1_INIT | ICW1_ICW4);
    port.io_wait();
    port.outb(PIC_MASTER_DATA, offsetMaster); // ICW2: Master PIC vector offset
    port.io_wait();
    port.outb(PIC_SLAVE_DATA, offsetSlave); // ICW2: Slave PIC vector offset
    port.io_wait();
    port.outb(PIC_MASTER_DATA, 4); // ICW3: tell Master PIC that there is a slave PIC at IRQ2 (0000 0100)
    port.io_wait();
    port.outb(PIC_SLAVE_DATA, 2); // ICW3: tell Slave PIC its cascade identity (0000 0010)
    port.io_wait();

    port.outb(PIC_MASTER_DATA, ICW4_8086); // ICW4: have the PICs use 8086 mode (and not 8080 mode)
    port.io_wait();
    port.outb(PIC_SLAVE_DATA, ICW4_8086);
    port.io_wait();

    picDisable();
    port.outb(PIC_SLAVE_DATA, port.inb(PIC_SLAVE_DATA) & ~@as(u8, 0x10)); // idk Enable cascade interrupt?

    debug.printf("pic changed the base offset in the idt\n", .{});
}

pub fn maskIRQ(irq: u8, mask: bool) void {
    const localPort: u16 = if (irq < 8) PIC_MASTER_DATA else PIC_SLAVE_DATA;
    const old = port.inb(localPort);

    const shift: u3 = @intCast(irq % 8);
    if (mask) {
        port.outb(localPort, old | (@as(u8, 1) << shift));
    } else {
        port.outb(localPort, old & ~(@as(u8, 1) << shift));
    }
    // debug.printf("irq masking debug: 0x{X} -> 0x{X}\n", .{ old, port.inb(localPort) });
}

const PIC_READ_IRR = 0x0a; // OCW3 irq ready next CMD read
const PIC_READ_ISR = 0x0b; // OCW3 irq service next CMD read

/// OCW3 to PIC CMD to get the register values.  PIC2 is chained, and
/// represents IRQs 8-15.  PIC1 is IRQs 0-7, with 2 being the chain
fn picGetIrqReg(ocw3: u8) u16 {
    port.outb(PIC_MASTER_COMMAND, ocw3);
    port.outb(PIC_SLAVE_COMMAND, ocw3);
    return (@as(u16, @intCast(port.inb(PIC_SLAVE_COMMAND))) << 8) | port.inb(PIC_MASTER_COMMAND);
}

/// Returns the combined value of the cascaded PICs irq request register
pub fn picGetIrr() u16 {
    return picGetIrqReg(PIC_READ_IRR);
}

/// Returns the combined value of the cascaded PICs in-service register
pub fn picGetIsr() u16 {
    return picGetIrqReg(PIC_READ_ISR);
}

pub fn installIrq(interrupt: *const fn () callconv(.naked) void, irqNumber: u8) !void {
    try idt.openIdtGate(irqNumber + PIC_MASTER_OFFSET, interrupt);
    maskIRQ(irqNumber, false);
}

pub fn initPic() void {
    disableApic();
    debug.printf("disabled the APIC\n", .{}); // should make the system/cpu emualte 8259 pic

    picRemap(PIC_MASTER_OFFSET, PIC_SLAVE_OFFSET);

    asm volatile ("sti");
}

fn disableApic() void {
    const apicBase = utils.cpuGetMSR(0x1B);
    utils.cpuSetMSR(0x1B, apicBase & ~@as(u64, 1 << 11));
}
