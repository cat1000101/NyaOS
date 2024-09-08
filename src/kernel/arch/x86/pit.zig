const DATA_0 = 0x40; //         Channel 0 data port (read/write)
const DATA_1 = 0x41; //         Channel 1 data port (read/write)
const DATA_2 = 0x42; //         Channel 2 data port (read/write)
const COMMAND_REGISTER = 0x43; //         Mode/Command register (write only, a read is ignored)

const pitCommandRegister = packed struct {
    BCD: u1, // 0 = 16-bit binary, 1 = four-digit BCD
    operatingMode: u3, // Mode 0 (interrupt on terminal count)
    // Mode 1 (hardware re-triggerable one-shot)
    // Mode 2 (rate generator)
    // Mode 3 (square wave generator)
    // Mode 4 (software triggered strobe)
    // Mode 5 (hardware triggered strobe)
    // Mode 2 (rate generator, same as 010b)
    // Mode 3 (square wave generator, same as 011b)
    accessMode: u2, // 0 0 = Latch count value command
    //0 1 = Access mode: lobyte only
    //1 0 = Access mode: hibyte only
    //1 1 = Access mode: lobyte/hibyte
    selectChannel: u2, // 0 0 = Channel 0
    // 0 1 = Channel 1
    // 1 0 = Channel 2
    // 1 1 = Read-back command (8254 only)

};
