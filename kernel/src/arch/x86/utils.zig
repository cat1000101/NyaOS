pub fn hlt() void {
    asm volatile ("hlt");
    while (true) asm volatile ("");
}

pub fn whileTrue() void {
    while (true) asm volatile ("");
}

/// pretty useless unless using like anciant hardware
fn cpuHasMSR() bool {
    const cpuid = cpuidFeature();
    return (cpuid & (1 << 5)) != 0;
}

pub fn cpuidFeature() u32 {
    var ret: u32 = 0;
    asm volatile (
        \\ cpuid
        : [ret] "={edx}" (ret),
        : [value] "{eax}" (1),
        : "ebx", "ecx", "eax"
    );
    return ret;
}

pub fn cpuGetMSR(msr: u32) u64 {
    var low: u32 = 0;
    var high: u32 = 0;
    asm volatile (
        \\ rdmsr
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
        : [msr] "{ecx}" (msr),
    );
    return ((@as(u64, high) << 32) | @as(u64, low));
}

pub fn cpuSetMSR(msr: u32, value: u64) void {
    const low: u32 = @intCast(value & 0xFFFFFFFF);
    const high: u32 = @intCast(value >> 32);
    asm volatile (
        \\ wrmsr
        :
        : [msr] "{ecx}" (msr),
          [low] "{eax}" (low),
          [high] "{edx}" (high),
    );
}
