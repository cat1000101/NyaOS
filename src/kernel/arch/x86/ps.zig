const DATA_READ_WRITE = 0x60;
const STATUS_READ = 0x64;
const COMMAND_WRITE = 0x64;

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

pub fn init() void {}
