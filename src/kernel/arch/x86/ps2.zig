const acpi = @import("acpi.zig");
const port = @import("port.zig");
const virtio = @import("virtio.zig");

const DATA_READ_WRITE = 0x60;
const STATUS_READ = 0x64;
const COMMAND_WRITE = 0x64;

const ps2Errors = error{
    ps2ControllerNotPresent,
};

const statusRegister = packed struct {
    outputBufferStatus: u1, // (must be set before attempting to read data from IO port 0x60)
    inputBufferStatus: u1, // (must be clear before attempting to write data to IO port 0x60 or IO port 0x64)
    systemFlag: u1, // Meant to be cleared on reset and set by firmware (via. PS/2 Controller Configuration Byte) if the system passes self tests (POST)
    commandOrData: u1, //  (0 = data written to input buffer is data for PS/2 device, 1 = data written to input buffer is data for PS/2 controller command)
    unknown: u1, // (chipset specific)
    unknown2: u1, // (chipset specific)
    timeOut: u1, // (0 = no error, 1 = time-out error)
    parity: u1, //  (0 = no error, 1 = parity error)
};

const controllerConfiguration = packed struct {
    firstPortInterrupt: u1, // (0 = disabled, 1 = enabled)
    secondPortInterrupt: u1, // (0 = disabled, 1 = enabled)
    systemFlag: u1, // (0 = system failed POST, 1 = system passed POST)
    zero: u1 = 0, // (must be 0)
    firstPortClock: u1, // (1 = disabled, 0 = enabled)
    secondPortClock: u1, // (1 = disabled, 0 = enabled)
    firstPortTranslation: u1, // (0 = disabled, 1 = enabled)
    zero2: u1 = 0, // (must be 0)
};

const controllerOutput = packed struct {
    systemReset: u1 = 1, // scary no touch please
    a20Gate: u1,
    secondPortClock: u1,
    secondPortData: u1,
    byteFromFirstPort: u1, // (connected to IRQ1)
    byteFromSecondPort: u1, // (connected to IRQ12)
    firstPortClock: u1,
    firstPortData: u1,
};

fn ps2ControllerExists(acpiTables: ?acpi.acpiTables) bool {
    const LocalAcpiTables = acpiTables orelse return true;
    return (LocalAcpiTables.fadt.iapc_boot_arch_flags & 2) == 2;
}

pub fn init(acpiTables: ?acpi.acpiTables) ps2Errors!void {
    // TODO: this whole thing
    // TODO: usb stuff
    if (!ps2ControllerExists(acpiTables)) {
        virtio.printf("ps2 controller not present sad\n", .{});
        return ps2Errors.ps2ControllerNotPresent;
    }
    port.outb(COMMAND_WRITE, 0xAD); // disable first port
    port.outb(COMMAND_WRITE, 0xA7); // disable second port
    _ = port.inb(DATA_READ_WRITE); // flush
}
