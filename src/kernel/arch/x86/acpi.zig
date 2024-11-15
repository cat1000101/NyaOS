const virtio = @import("virtio.zig");
const port = @import("port.zig");
const std = @import("std");

const RSDP_FINDING_POSITION: [2]u32 = [2]u32{ 0x000E0000, 0x000FFFFF };
const IDENTIFIER = "RSD PTR ";
const FADT_SIGNATURE = "FACP";

pub const acpiErrors = error{
    NotFound,
    InvalidChecksum,
    InvalidSignature,
    AlreadyInitialized,
};

pub const acpiTables = struct {
    rsdp: *RSDP,
    fadt: *FADT,
};

pub const RSDP align(1) = extern struct {
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

pub const SDTHeader align(1) = extern struct {
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
pub const RSDT align(1) = extern struct {
    h: SDTHeader,
    entries: u32, // [(@This().h.length - @sizeOf(SDTHeader)) / @sizeOf(u32)]*SDTHeader,
};

pub const XSDT align(1) = extern struct {
    h: SDTHeader,
    entries: u64, // [(@This().h.length - @sizeOf(SDTHeader)) / @sizeOf(u32)]*SDTHeader,
};

pub const genericAddressStructure align(1) = extern struct {
    address_space: u8,
    bit_width: u8,
    bit_offset: u8,
    access_size: u8,
    address: u64,
};

// TODO: fix this bug alignment being weird in zig maybe will be fixed through a bug report
pub const FADT align(1) = extern struct {
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

const CHECKSUM_LENGTH_V1: usize = @offsetOf(RSDP, "length");
const CHECKSUM_LENGTH_V2: usize = @sizeOf(RSDP);

fn findRSDP() acpiErrors!*RSDP {
    var i = RSDP_FINDING_POSITION[0];
    while (i <= RSDP_FINDING_POSITION[1]) : (i += 16) {
        const ptr: *RSDP = @ptrFromInt(i);
        if (std.mem.eql(u8, &ptr.signature, IDENTIFIER)) {
            return ptr;
        }
    }
    virtio.printf("rsdp not found? {}\n", .{acpiErrors.NotFound});
    return acpiErrors.NotFound;
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

fn getFADT(rsdp: *RSDP) acpiErrors!*FADT {
    const rsdt = rsdp.rsdt_address;
    const enteries = (rsdt.h.length - @sizeOf(SDTHeader)) / @sizeOf(u32);
    const enteriesArray: [*]*SDTHeader = @ptrCast(&rsdt.entries);
    for (0..enteries) |i| {
        const header: *SDTHeader = enteriesArray[i];
        if (std.mem.eql(u8, &header.signature, FADT_SIGNATURE)) {
            const ret: *FADT = @ptrCast(header);
            return ret;
        }
    }
    virtio.printf("fadt not found? {}\n", .{acpiErrors.NotFound});
    return acpiErrors.NotFound;
}

pub fn initACPI() acpiErrors!acpiTables {
    const rsdp: *RSDP = try findRSDP();
    if (!validationRsdpChecksum(rsdp)) {
        virtio.printf("rsdp checksum failed\n", .{});
        return acpiErrors.InvalidChecksum;
    }
    const fadt: *FADT = try getFADT(rsdp);
    if (!validationChecksum(@ptrCast(fadt))) {
        virtio.printf("fadt checksum failed\n", .{});
        return acpiErrors.InvalidChecksum;
    }

    if (fadt.smi_command_port == 0 and fadt.acpi_enable == 0 and fadt.acpi_disable == 0 and (fadt.pm1a_control_block & 1) == 1) {
        virtio.printf("acpi not supported or already enabled?\n", .{}); // i think there is miss information but idk
        return acpiErrors.AlreadyInitialized;
    }

    port.outb(@intCast(fadt.smi_command_port), fadt.acpi_enable);

    virtio.printf("acpi init success yippe\n", .{});
    return acpiTables{ .rsdp = rsdp, .fadt = fadt };
}
