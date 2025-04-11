const debug = @import("../arch/x86/debug.zig");
const port = @import("../arch/x86/port.zig");
const std = @import("std");
const vmm = @import("../mem/vmm.zig");

const RSDP_FINDING_POSITION: [2]u32 = [2]u32{ 0x000E0000, 0x000FFFFF };
const IDENTIFIER = "RSD PTR ";
const FADT_SIGNATURE = "FACP";
const APIC_SIGNATURE = "APIC";

pub const acpiErrors = error{
    NotFound,
    InvalidChecksum,
    InvalidSignature,
    AlreadyInitialized,
};

pub const acpiTables = struct {
    rsdp: ?*RSDP,
    fadt: ?*FADT,
};

pub const RSDP = extern struct {
    signature: [8]u8,
    checksum: u8,
    oem_id: [6]u8,
    revision: u8,
    rsdt_address: *RSDT,

    length: u32,
    xsdt_address: *XSDT,
    extended_checksum: u8,
    reserved: [3]u8,
};

pub const SDTHeader = extern struct {
    signature: [4]u8,
    length: u32,
    revision: u8,
    checksum: u8,
    oem_id: [6]u8,
    oem_table_id: [8]u8,
    oem_revision: u32,
    creator_id: u32,
    creator_revision: u32,
};

pub const RSDT = extern struct {
    h: SDTHeader,
    entries: u32, // [(@This().h.length - @sizeOf(SDTHeader)) / @sizeOf(u32)]*SDTHeader,
};

pub const XSDT = extern struct {
    h: SDTHeader,
    entries: u64, // [(@This().h.length - @sizeOf(SDTHeader)) / @sizeOf(u32)]*SDTHeader,
};

pub const genericAddressStructure = extern struct {
    address_space: u8,
    bit_width: u8,
    bit_offset: u8,
    access_size: u8,
    address: u64,
};

// TODO: fix this bug alignment being weird in zig maybe will be fixed through a bug report
pub const FADT = extern struct {
    h: SDTHeader,
    firmware_control: u32,
    dsdt: u32,

    reserved: u8,

    preferred_pm_profile: u8,
    sci_interrupt: u16,
    smi_command_port: u32,
    acpi_enable: u8,
    acpi_disable: u8,
    s4bios_req: u8,
    pstate_control: u8,

    pm1a_event_block: u32,
    pm1b_event_block: u32,
    pm1a_control_block: u32,
    pm1b_control_block: u32,
    pm2_control_block: u32,
    pm_timer_block: u32,
    gpe0_block: u32,
    gpe1_block: u32,

    pm1_event_length: u8,
    pm1_control_length: u8,
    pm2_control_length: u8,
    pm_timer_length: u8,
    gpe0_length: u8,
    gpe1_length: u8,
    gpe1_base: u8,
    cstate_control: u8,
    worst_c2_latency: u16,
    worst_c3_latency: u16,
    flush_size: u16,
    flush_stride: u16,
    duty_offset: u8,
    duty_width: u8,
    day_alarm: u8,
    month_alarm: u8,
    century: u8,

    iapc_boot_arch_flags: u16 align(1),

    reserved2: u8,
    flags: u32,

    reset_reg: genericAddressStructure,

    reset_value: u8,
    reserved3: [3]u8,

    x_firmware_control: u64,
    x_dsdt: u64,

    x_pm1a_event_block: genericAddressStructure,
    x_pm1b_event_block: genericAddressStructure,
    x_pm1a_control_block: genericAddressStructure,
    x_pm1b_control_block: genericAddressStructure,
    x_pm2_control_block: genericAddressStructure,
    x_pm_timer_block: genericAddressStructure,
    x_gpe0_block: genericAddressStructure,
    x_gpe1_block: genericAddressStructure,
};

const recordHeader = struct {
    recordType: u8,
    recordLength: u8,
};

pub const MADT align(1) = packed struct {
    h: SDTHeader,
    local_controller_address: u32,
    flags: u32,
};

const CHECKSUM_LENGTH_V1: usize = @offsetOf(RSDP, "length");
const CHECKSUM_LENGTH_V2: usize = @sizeOf(RSDP);

fn findRSDP() ?*RSDP {
    var i = RSDP_FINDING_POSITION[0];
    while (i <= RSDP_FINDING_POSITION[1]) : (i += 16) {
        const ptr: *RSDP = @ptrFromInt(i);
        if (std.mem.eql(u8, &ptr.signature, IDENTIFIER)) {
            return ptr;
        }
    }
    debug.printf("rsdp not found?\n", .{});
    return null;
}

fn validationRsdpChecksum(rsdp: *RSDP) bool {
    var size: usize = undefined;
    if (rsdp.revision == 0) {
        size = CHECKSUM_LENGTH_V1;
    } else {
        size = CHECKSUM_LENGTH_V2;
    }
    return calculateChecksum(@ptrCast(rsdp), size);
}

fn validationChecksum(header: *SDTHeader) bool {
    return calculateChecksum(@ptrCast(header), header.length);
}

fn calculateChecksum(ptr: [*]u8, length: usize) bool {
    var sum: u8 = 0;
    for (0..length) |i| {
        sum +%= ptr[i];
    }
    return sum == 0;
}

fn getFADT() ?*FADT {
    return @ptrCast(findTable(FADT_SIGNATURE));
}

pub fn findTable(signature: []const u8) ?*SDTHeader {
    const localRsdp = tables.rsdp orelse {
        debug.printf("can't find table rsdp not found\n", .{});
        return null;
    };
    const rsdt = localRsdp.rsdt_address;
    const enteries = (rsdt.h.length - @sizeOf(SDTHeader)) / @sizeOf(u32);
    const enteriesArray: [*]*SDTHeader = @ptrCast(&rsdt.entries);
    for (0..enteries) |i| {
        const header: *SDTHeader = enteriesArray[i];
        if (std.mem.eql(u8, &header.signature, signature)) {
            return header;
        }
    }
    debug.printf("table not found with signiture {s}\n", .{signature});
    return null;
}

pub fn ps2ControllerExists() bool {
    if (tables.fadt) |fadt| {
        return (fadt.iapc_boot_arch_flags & 2) == 2;
    } else {
        return true;
    }
}

fn extraTables() void {
    return;
}

pub var tables: acpiTables = .{ .fadt = null, .rsdp = null };

pub fn initACPI() void {
    const rsdp: *RSDP = findRSDP() orelse return;
    tables.rsdp = rsdp;
    if (!validationRsdpChecksum(rsdp)) {
        debug.printf("rsdp checksum failed\n", .{});
        return;
    }
    const fadt: *FADT = getFADT() orelse return;
    tables.fadt = fadt;
    if (!validationChecksum(@ptrCast(fadt))) {
        debug.printf("fadt checksum failed\n", .{});
        return;
    }

    if (fadt.smi_command_port == 0 and fadt.acpi_enable == 0 and fadt.acpi_disable == 0 and (fadt.pm1a_control_block & 1) == 1) {
        debug.printf("acpi not supported or already enabled?\n", .{}); // i think there is miss information but idk
        return;
    }

    port.outb(@intCast(fadt.smi_command_port), fadt.acpi_enable);

    debug.printf("acpi init success yippe\n", .{});
}
