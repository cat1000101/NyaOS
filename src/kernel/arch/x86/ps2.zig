const acpi = @import("acpi.zig");
const port = @import("port.zig");
const virtio = @import("virtio.zig");

const DATA_READ_WRITE = 0x60;
const STATUS_READ = 0x64;
const COMMAND_WRITE = 0x64;

const ps2Errors = error{
    ps2ControllerNotPresent,
    ps2CommandTimeout,
    ps2SelfTestFailed,
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

const controllerComands = enum(u8) {
    readControllerConfiguration = 0x20,
    writeControllerConfiguration = 0x60,
    disableFirstPort = 0xAD,
    disableSecondPort = 0xA7,
    enableFirstPort = 0xAE,
    enableSecondPort = 0xA8,
    testFirstPort = 0xAB,
    testSecondPort = 0xA9,
    testController = 0xAA,
    selfTest = 0xAA,
    interfaceTest = 0xAB,
    diagnosticDump = 0xAC,
    disableFirstPortClock = 0x10,
    disableSecondPortClock = 0x20,
    enableFirstPortClock = 0x11,
    enableSecondPortClock = 0x21,
    readOutputPort = 0xD0,
    writeOutputPort = 0xD1,
    writeSecondPortOutput = 0xD3,
    writeSecondPortInput = 0xD4,
    _,
};

fn ps2ControllerExists(acpiTables: ?acpi.acpiTables) bool {
    const LocalAcpiTables = acpiTables orelse return true;
    return (LocalAcpiTables.fadt.iapc_boot_arch_flags & 2) == 2;
}

inline fn readStatus() statusRegister {
    return @bitCast(port.inb(STATUS_READ));
}

fn sendCommand(command: u8) void {
    while (true) {
        const status = readStatus();
        if (status.inputBufferStatus == 0) {
            break;
        }
    }
    port.outb(COMMAND_WRITE, command);
}

fn reciveData() u8 {
    while (true) {
        const status = readStatus();
        if (status.outputBufferStatus == 1) {
            break;
        }
    }
    return port.inb(DATA_READ_WRITE);
}

fn sendData(data: u8) void {
    while (true) {
        const status = readStatus();
        if (status.inputBufferStatus == 0) {
            break;
        }
    }
    port.outb(DATA_READ_WRITE, data);
}

pub fn initPs2(acpiTables: ?acpi.acpiTables) !void {
    // TODO: this whole thing
    // TODO: usb stuff
    if (!ps2ControllerExists(acpiTables)) {
        virtio.printf("ps2 controller not present sad\n", .{});
        return ps2Errors.ps2ControllerNotPresent;
    }
    sendCommand(0xAD); // disable first port
    sendCommand(0xA7); // disable second port

    _ = port.inb(DATA_READ_WRITE); // flush

    // Set the Controller Configuration Byte
    sendCommand(0x20);
    const psConfiguration: controllerConfiguration = @bitCast(reciveData()); // read controller configuration
    var newPsconfiguration = psConfiguration;
    newPsconfiguration.firstPortInterrupt = 0;
    newPsconfiguration.firstPortTranslation = 0;
    newPsconfiguration.firstPortClock = 0;
    sendCommand(0x60);
    sendData(@bitCast(newPsconfiguration));

    sendCommand(0xAA); // self test
    if (reciveData() != 0x55) {
        virtio.printf("ps2 self test failed\n", .{});
        sendCommand(0x60);
        sendData(@bitCast(psConfiguration));
        return ps2Errors.ps2SelfTestFailed;
    }
}
