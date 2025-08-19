const acpi = @import("acpi.zig");
const port = @import("../arch/x86/port.zig");
const interrupts = @import("../arch/x86/interrupts.zig");
const pic = @import("../arch/x86/pic.zig");
const tty = @import("tty.zig");
const debug = @import("../arch/x86/debug.zig");

const log = @import("std").log;

const DATA_READ_WRITE: u16 = 0x60;
const STATUS_READ: u16 = 0x64;
const COMMAND_WRITE: u16 = 0x64;
var ps2status: ps2State = .{};

const ps2State = packed struct {
    firstPort: bool = false,
    secondPort: bool = false,
    dualChannel: bool = false,
};

const ps2Errors = error{
    ps2ControllerNotPresent,
    ps2CommandTimeout,
    ps2SelfTestFailed,
    ps2SecondPortNotPresent,
    ps2FirstPortNotPresent,
    ps2FirstPortResetFailed,
    ps2SecondPortResetFailed,
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

inline fn readStatus() statusRegister {
    return @bitCast(port.inb(STATUS_READ));
}

fn sendCommand(command: u8) void {
    var timeout: u32 = 0;
    while (true) : (timeout += 1) {
        const status = readStatus();
        if (status.inputBufferStatus == 0) {
            break;
        } else if (timeout == 100000) {
            log.err("sendCommand:  ps2 sendCommand timeout status: {}\n", .{status});
        }
    }
    port.outb(COMMAND_WRITE, command);
}

fn reciveData() u8 {
    var timeout: u32 = 0;
    while (true) : (timeout += 1) {
        const status = readStatus();
        if (status.outputBufferStatus == 1) {
            break;
        } else if (timeout == 100000) {
            log.err("reciveData:  ps2 reciveData timeout status: {}\n", .{status});
        }
    }
    const data = port.inb(DATA_READ_WRITE);
    return data;
}

fn sendData(data: u8) void {
    var timeout: u32 = 0;
    while (true) : (timeout += 1) {
        const status = readStatus();
        if (status.inputBufferStatus == 0) {
            break;
        } else if (timeout == 100000) {
            log.err("sendData:  ps2 sendData timeout status: {}\n", .{status});
        }
    }
    port.outb(DATA_READ_WRITE, data);
}

fn sendDataPort2(data: u8) void {
    var timeout: u32 = 0;
    sendCommand(0xD4);
    while (true) : (timeout += 1) {
        const status = readStatus();
        if (status.inputBufferStatus == 0) {
            break;
        } else if (timeout == 100000) {
            log.err("sendDataPort2:  ps2 sendDataPort2 timeout status: {}\n", .{status});
        }
    }
    port.outb(DATA_READ_WRITE, data);
}

fn getControllerConfiguration() controllerConfiguration {
    disableFirstPort();
    sendCommand(0x20);
    const ret: controllerConfiguration = @bitCast(reciveData());
    enableFirstPort();
    return ret;
}

fn setControllerConfiguration(config: controllerConfiguration) void {
    disableFirstPort();
    sendCommand(0x60);
    sendData(@bitCast(config));
    enableFirstPort();
}

fn enableFirstPort() void {
    sendCommand(0xAE);
}

fn disableFirstPort() void {
    sendCommand(0xAD);
}

fn enableSecondPort() void {
    sendCommand(0xA8);
}

fn disableSecondPort() void {
    sendCommand(0xA7);
}

fn initializePs2() !void {
    // TODO: usb stuff
    if (!acpi.ps2ControllerExists()) {
        log.err("ps2 controller not present sad\n", .{});
        return ps2Errors.ps2ControllerNotPresent;
    }

    disableKeyboard();

    disableFirstPort(); // disable first port
    disableSecondPort(); // disable second port

    _ = reciveData(); // flush

    // Set the Controller Configuration Byte
    var psConfiguration = getControllerConfiguration(); // read controller configuration
    var newPsconfiguration = psConfiguration;
    newPsconfiguration.firstPortInterrupt = 0;
    newPsconfiguration.secondPortInterrupt = 0;
    setControllerConfiguration(newPsconfiguration);

    // self test
    sendCommand(0xAA);
    if (reciveData() != 0x55) {
        log.err("initializePs2:  ps2 self test failed\n", .{});
        setControllerConfiguration(psConfiguration);
        return ps2Errors.ps2SelfTestFailed;
    }

    // Determine If There Are 2 Channels
    enableSecondPort();

    psConfiguration = getControllerConfiguration();
    if (psConfiguration.secondPortClock != 1) {
        disableSecondPort();
        ps2status.dualChannel = true;
    } else {
        log.info("single channel\n", .{});
    }

    // Perform Interface Tests
    sendCommand(0xAB);
    if (reciveData() == 0) {
        ps2status.firstPort = true;
    } else {
        log.err("initializePs2:  ps2 first channel/port not aviable/not pasted the self test\n", .{});
    }
    if (ps2status.dualChannel) {
        sendCommand(0xA9);
        if (reciveData() == 0) {
            ps2status.secondPort = true;
        } else {
            log.err("initializePs2:  ps2 second channel/port not aviable/not pasted the self test\n", .{});
        }
    }

    // enable ports and interrupts for them
    psConfiguration = getControllerConfiguration();
    if (ps2status.firstPort) {
        enableFirstPort();
        psConfiguration.firstPortInterrupt = 1;
    }
    if (ps2status.secondPort) {
        enableSecondPort();
        psConfiguration.secondPortInterrupt = 1;
    }
    setControllerConfiguration(psConfiguration);

    // Reset Devices
    if (ps2status.firstPort) {
        sendData(0xFF);
        var data = reciveData();
        if (data != 0xFA) {
            log.err("initializePs2:  ps2 first port reset failed\n", .{});
            return ps2Errors.ps2FirstPortResetFailed;
        }
        data = reciveData();
        if (data != 0xAA) {
            log.err("initializePs2:  ps2 first port reset failed\n", .{});
            return ps2Errors.ps2FirstPortResetFailed;
        }
    }
    if (ps2status.secondPort) {
        sendDataPort2(0xFF);
        var data = reciveData();
        if (data != 0xFA) {
            log.err("initializePs2:  ps2 second port reset failed\n", .{});
            return ps2Errors.ps2SecondPortResetFailed;
        }
        data = reciveData();
        if (data != 0xAA) {
            log.err("initializePs2:  ps2 second port reset failed\n", .{});
            return ps2Errors.ps2SecondPortResetFailed;
        }
    }

    // final flush and status
    log.debug("initializePs2:  final ps2 controller config: 0x{X}\n", .{@as(u8, @bitCast(getControllerConfiguration()))});

    _ = reciveData();

    log.info("ps2 controller initialized\n", .{});
}

pub fn initPs2() void {
    initializePs2() catch |err| {
        log.err("initPs2:  failed to initialize ps2 {}\n", .{err});
    };

    initializeKeyboard();
}

// -------------------- Keyboard/Mice driver --------------------

const keyboardIdentifier = enum(u16) {
    standardPs2Mouse = 0x00FF,
    scrollWheelMouse = 0x03FF,
    fiveButtonMouse = 0x04FF,
    MF2keyboard = 0xAB83,
    MF2keyboard2 = 0xABC1,
    MF2keyboard3 = 0xAB41,
    IBMshortKeyboard = 0xAB84,
    NCDkeyboard = 0xAB85,
    kayboard122 = 0xAB86,
    japaneaseKeyboardG = 0xAB90,
    japaneaseKeyboardP = 0xAB91,
    japaneaseKeyboardA = 0xAB92,
    NCDsunKeyboard = 0xACA1,
    bleh = 0xFFFF,
    _,
};

const scanCodeSet1 = [_]u8{
    0,   0,   '1', '2', '3', '4', '5', '6', '7',  '8', '9', '0',  '-', '=', 0,   0,
    'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O',  'P', '[', ']',  0,   0,   'A', 'S',
    'D', 'F', 'G', 'H', 'J', 'K', 'L', ';', '\'', '`', 0,   '\\', 'Z', 'X', 'C', 'V',
    'B', 'N', 'M', ',', '.', '/', 0,   '*', 0,    ' ', 0,   0,    0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,    0,   0,   0,    0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,    0,   0,   0,    0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,    0,   0,   0,    0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,    0,   0,   0,
};

fn getDeviceId() keyboardIdentifier {
    disableFirstPort();
    sendCommand(0xF5);
    if (reciveData() != 0xFA) {
        log.err("getDeviceId:  ps2 getDeviceId failed\n", .{});
        return .bleh;
    }
    sendCommand(0xF2);
    if (reciveData() != 0xFA) {
        log.err("getDeviceId:  ps2 getDeviceId failed2\n", .{});
        return .bleh;
    }
    var data: [2]u8 = undefined;
    data[0] = reciveData();
    data[1] = reciveData();
    sendData(0xF4);
    const ret: keyboardIdentifier = @enumFromInt(@as(u16, @bitCast(data)));
    enableFirstPort();
    return ret;
}

fn enableKeyboard() void {
    // log.info("the keyboard type: {s}\n", .{@tagName(getDeviceId())});
    sendData(0xF4);
    var newConfig = getControllerConfiguration();
    newConfig.firstPortInterrupt = 1;
    setControllerConfiguration(newConfig);
}

fn disableKeyboard() void {
    sendData(0xF5);
}

fn initializeKeyboard() void {
    const keyboardHandeler = comptime interrupts.generateStub(&ps2KeyboardHandeler);
    pic.installIrq(&keyboardHandeler, 1) catch |err| {
        log.err("initializeKeyboard:  failed to install keyboard handeler {}\n", .{err});
    };
    enableKeyboard();
    log.info("keyboard initialized!!!\n", .{});
}

pub const keyboardData = extern struct {
    scancode: u8 = 0,
    ascii: u8 = 0,
    modifiers: u8 = 0,
    pad: u8 = 0,
};
pub var kayboardData: [64]keyboardData = [_]keyboardData{.{}} ** 64;
pub var currentKey: usize = 0;
var extendedCode: usize = 0; // 0 - no, 1 - 0xe0 extended code, 2 - 0xe1 extended code 3 - 0xe1 extended code final
fn ps2KeyboardHandeler(cpuState: *interrupts.CpuState) callconv(.c) void {
    _ = cpuState;
    if (readStatus().outputBufferStatus == 0) {
        log.err("ps2KeyboardHandeler:  keyboard handeler called with no data\n", .{});
        pic.picSendEOI(1);
        return;
    }

    var finalData: u8 = 0;
    var pressed: bool = false;
    const data1 = reciveData();
    if (data1 == 0xE0) {
        extendedCode = 1;
        pic.picSendEOI(1);
        return;
    } else if (data1 == 0xE1) {
        extendedCode = 2;
        pic.picSendEOI(1);
        return;
    } else {
        if (data1 < 0x80) {
            finalData = data1;
            pressed = true;
        } else {
            finalData = data1 - 0x80;
        }
    }
    if (extendedCode == 2) {
        extendedCode = 3;
    } else if (extendedCode == 3) {
        extendedCode = 0;
        pic.picSendEOI(1);
        return;
    }

    const char = scanCodeSet1[finalData];
    kayboardData[currentKey].scancode = finalData;
    kayboardData[currentKey].ascii = char;
    kayboardData[currentKey].modifiers = @intFromBool(pressed);
    currentKey = (currentKey + 1) % kayboardData.len;
    extendedCode = 0;

    if (pressed) {
        debug.putcharAsm(char);
        tty.putChar(char);
    }

    pic.picSendEOI(1);
}

pub fn getKey() keyboardData {
    const retData = kayboardData[currentKey];
    kayboardData[currentKey].scancode = 0;
    kayboardData[currentKey].ascii = 0;
    kayboardData[currentKey].modifiers = 0;
    if (currentKey == 0) {
        currentKey = kayboardData.len - 1;
    } else {
        currentKey -= 1;
    }
    return retData;
}
