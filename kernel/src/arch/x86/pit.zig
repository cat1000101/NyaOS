const debug = @import("debug.zig");
const port = @import("port.zig");
const pic = @import("pic.zig");
const interrupts = @import("interrupts.zig");

const CHANNEL_0_PORT: u16 = 0x40;
const CHANNEL_1_PORT: u16 = 0x41;
const CHANNEL_2_PORT: u16 = 0x42;
const COMMAND_PORT: u16 = 0x43;

const PIT_FREQUENCY: u32 = 1193182; // 1.193182 MHz

// docs for this chip that i used are at https://wiki.osdev.org/Programmable_Interval_Timer

const commandRegister = packed struct {
    /// BCD/Binary mode: 0 = 16-bit binary, 1 = four-digit BCD, x86 computers only use binary mode so i will make it deafult
    bcdOrBianry: u1 = 0,
    /// Operating mode :
    ///   0 0 0 = Mode 0 (interrupt on terminal count),
    ///   0 0 1 = Mode 1 (hardware re-triggerable one-shot),
    ///   0 1 0 = Mode 2 (rate generator),
    ///   0 1 1 = Mode 3 (square wave generator),
    ///   1 0 0 = Mode 4 (software triggered strobe),
    ///   1 0 1 = Mode 5 (hardware triggered strobe),
    ///   1 1 0 = Mode 2 (rate generator, same as 010b),
    ///   1 1 1 = Mode 3 (square wave generator, same as 011b)
    opratationMode: u3,
    /// Access mode :
    ///    0 0 = Latch count value command,
    ///    0 1 = Access mode: lobyte only,
    ///    1 0 = Access mode: hibyte only,
    ///    1 1 = Access mode: lobyte/hibyte
    access: u2,
    /// Select channel :
    ///    0 0 = Channel 0,
    ///    0 1 = Channel 1,
    ///    1 0 = Channel 2,
    ///    1 1 = Read-back command (8254 only)
    channel: u2,
};
const PIT_CONFIGURATION = commandRegister{
    .bcdOrBianry = 0,
    .opratationMode = 0b011, // rate generator // square wave generator
    .access = 0b11, // lobyte/hibyte
    .channel = 0b00, // channel 0
};

const readBackCommand = packed struct {
    /// Reserved (should be clear)
    reserved: u1 = 0,
    /// Read back timer channel 0 (1 = yes, 0 = no)
    readBackChannel0: u1,
    /// Read back timer channel 1 (1 = yes, 0 = no)
    readBackChannel1: u1,
    /// Read back timer channel 2 (1 = yes, 0 = no)
    readBackChannel2: u1,
    /// Latch status flag (0 = latch status, 1 = don't latch status)
    latchStatus: u1,
    /// Latch count flag (0 = latch count, 1 = don't latch count)
    latchCount: u1,
    /// Must be set for the read back command
    one: u2 = 0b11,
};

const readBackStatus = packed struct {
    /// BCD/Binary mode: 0 = 16-bit binary, 1 = four-digit BCD
    bcdOrBianry: u1,
    /// Operating mode :
    ///    0 0 0 = Mode 0 (interrupt on terminal count)
    ///    0 0 1 = Mode 1 (hardware re-triggerable one-shot)
    ///    0 1 0 = Mode 2 (rate generator)
    ///    0 1 1 = Mode 3 (square wave generator)
    ///    1 0 0 = Mode 4 (software triggered strobe)
    ///    1 0 1 = Mode 5 (hardware triggered strobe)
    ///    1 1 0 = Mode 2 (rate generator, same as 010b)
    ///    1 1 1 = Mode 3 (square wave generator, same as 011b)
    operatingMode: u3,
    /// Access mode :
    ///    0 0 = Latch count value command
    ///    0 1 = Access mode: lobyte only
    ///    1 0 = Access mode: hibyte only
    ///    1 1 = Access mode: lobyte/hibyte
    access: u2,
    /// indicates whether a newly-programmed divisor value has been loaded into the current count yet (if clear)
    /// or the channel is still waiting for a trigger signal
    /// or for the current count to count down to zero before a newly programmed reload value is loaded into the current count (if set).
    /// This bit is set when the mode/command register is initialized
    /// or when a new reload value is written, and cleared when the reload value is copied into the current count.
    countFlags: u1,
    /// Output pin state
    outPinState: u1,
};

pub fn readPitCount(channel: u8) u16 {
    const portAddress = switch (channel) {
        0 => CHANNEL_0_PORT,
        1 => CHANNEL_1_PORT,
        2 => CHANNEL_2_PORT,
        else => unreachable,
    };
    // channel in bits 6 and 7, remaining bits clear
    port.outb(COMMAND_PORT, 0b00000000 | (channel << 6));

    const lowByte: u16 = port.inb(portAddress);
    const highByte: u16 = port.inb(portAddress);
    return lowByte | (highByte << 8);
}

pub fn setPitCount(channel: u8, count: u16) void {
    const portAddress = switch (channel) {
        0 => CHANNEL_0_PORT,
        1 => CHANNEL_1_PORT,
        2 => CHANNEL_2_PORT,
        else => unreachable,
    };
    port.outb(portAddress, @truncate(count & 0xFF));
    port.outb(portAddress, @truncate((count >> 8) & 0xFF));
}

var timerFraction: u32 = 0;
var timerMs: u32 = 0;
var timerFrequency: u16 = 0;
var pitReloadValue: u16 = 0;

pub fn initPit(freq: u16) void {
    // the calculations is tolen from https://github.com/ZystemOS/pluto/blob/develop/src/kernel/arch/x86/pit.zig
    // 65536, the slowest possible frequency. Roughly 19Hz
    var reloadValue: u32 = 0x10000;

    // The lowest possible frequency is 18Hz.
    if (freq > 18) {
        if (freq < PIT_FREQUENCY) {
            // Rounded integer division
            reloadValue = (PIT_FREQUENCY + (freq / 2)) / freq;
        } else {
            // The fastest possible frequency if frequency is too high
            reloadValue = 1;
        }
    }

    const frequency: u32 = (PIT_FREQUENCY + (reloadValue / 2)) / reloadValue;
    timerFrequency = @truncate(frequency);

    // Calculate the amount of nanoseconds between interrupts
    timerMs = 1000 / frequency;
    timerFraction = 1000 % frequency;

    pitReloadValue = @truncate(reloadValue);

    debug.debugPrint("initPit:  ms: {}\n", .{timerMs});
    debug.debugPrint("initPit:  fraction: {}\n", .{timerFraction});
    debug.debugPrint("initPit:  frequency: {}\n", .{timerFrequency});
    debug.debugPrint("initPit:  ReloadValue: {}\n", .{reloadValue});
    debug.debugPrint("initPit:  pit reload value: {}\n", .{pitReloadValue});

    // set the command register
    port.outb(COMMAND_PORT, @bitCast(PIT_CONFIGURATION));
    setPitCount(0, pitReloadValue);

    const timerHandler = interrupts.generateStub(&pitHandler);
    pic.installIrq(&timerHandler, 0) catch |err| {
        debug.errorPrint("initPit:  failed to install timer handler {}\n", .{err});
    };

    // testSleep();
    debug.infoPrint("pit initialized :3\n", .{});
}

var timerMsSinceStart: u32 = 0;
var timerFractionSinceStart: u32 = 0;
var ticks: u32 = 0;
var countDown: u32 = 0;

fn pitHandler(cpuState: *interrupts.CpuState) callconv(.c) void {
    _ = cpuState;
    ticks += 1;
    timerMsSinceStart += timerMs;

    const fraction: u32 = timerFractionSinceStart + timerFraction;
    timerFractionSinceStart = fraction % timerFrequency;
    timerMsSinceStart += fraction / timerFrequency;

    if (countDown > 0) {
        countDown -= 1;
    }

    // debug.debugPrint("ms,fraction start: {}, {}\n", .{
    //     timerMsSinceStart,
    //     timerFractionSinceStart,
    // });

    pic.picSendEOI(0);
}

/// uses hlt which is a privliged instruction
pub fn ksleep(ms: u32) void {
    const startMs: u32 = timerMsSinceStart;
    const startFraction: f32 = @floatFromInt(timerFractionSinceStart);
    countDown = (ms * timerFrequency + 500) / 1000;
    while (countDown > 0) {
        interrupts.hlt();
    }
    const timePassedMs = @as(f32, @floatFromInt(timerMsSinceStart - startMs));
    const timePassed: f32 = timePassedMs + ((@as(f32, @floatFromInt(timerFractionSinceStart)) - startFraction) / @as(f32, @floatFromInt(timerFrequency)));
    debug.debugPrint("slept for {} ms, amount of ms passed: {d}~\n", .{
        ms,
        timePassed,
    });
}

pub fn getTimeMs() u32 {
    return timerMsSinceStart;
}

fn testSleep() void {
    debug.infoPrint("testing sleeping for 71ms\n", .{});
    ksleep(71);
}
