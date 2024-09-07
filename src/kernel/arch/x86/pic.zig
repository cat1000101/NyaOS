const port = @import("port.zig");

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

    port.outb(PIC_MASTER_DATA, PIC_EOI);
}

/// disables the pic
pub fn picDisable() void {
    port.outb(PIC_MASTER_DATA, 0xff);
    port.outb(PIC_SLAVE_DATA, 0xff);
}

/// remaps the pic offsets, recommanded for master 0x20 and for the slave 0x28
pub fn picRemap(offsetMaster: u8, offsetSlave: u8) void {
    var a1: u8 = undefined;
    var a2: u8 = undefined;

    a1 = port.inb(PIC_MASTER_DATA); // save masks
    a2 = port.inb(PIC_SLAVE_DATA);

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

    port.outb(PIC_MASTER_DATA, a1); // restore saved masks.
    port.outb(PIC_SLAVE_DATA, a2);
}
