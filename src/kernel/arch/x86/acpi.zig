const virtio = @import("virtio.zig");

const RSDP_FINDING_POSITION = []u32{ 0x000E0000, 0x000FFFFF };
const IDENTIFIER = "RSD PTR ";
const FADT_SIGNATURE = "FACP";

const acpiErrors = error{
    NotFound,
    InvalidChecksum,
    InvalidSignature,
};

const RSDP = packed struct {
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

const SDTHeader = packed struct {
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
const RSDT = packed struct {
    h: SDTHeader,
    entries: *[]u32,
};

const XSDT = packed struct {
    h: SDTHeader,
    entries: *[]u64,
};

const FADT = packed struct {};

const CHECKSUM_LENGTH_V1 = @sizeOf(RSDP) - @sizeOf(u8) * 4 - @sizeOf(u32) - @sizeOf(u64);
const CHECKSUM_LENGTH_V2 = @sizeOf(RSDP);

fn findRSDP() *RSDP {
    var rsdp: *RSDP = undefined;
    var i = RSDP_FINDING_POSITION[0];
    while (i <= RSDP_FINDING_POSITION[1]) : (i += 16) {
        const ptr: *RSDP = @ptrFromInt(i);
        if (ptr.signature == IDENTIFIER) {
            rsdp = ptr;
            break;
        }
    }
    if (rsdp == undefined) virtio.outb("where the hail is rsdp?");
    return rsdp;
}

fn validationChecksum(rsdp: *RSDP) bool {
    //var sum: u8 = 0;
    var size = undefined;
    if (rsdp.revision == 0) {
        size = CHECKSUM_LENGTH_V1;
    } else {
        size = CHECKSUM_LENGTH_V2;
    }
    return calculateChecksum(@ptrCast(rsdp), size);
}

fn calculateChecksum(ptr: *[]u8, length: usize) bool {
    var sum: u8 = 0;
    var index = ptr;
    while (index <= ptr + length) : (index += 1) {
        sum += index.*;
    }
    return sum == 0;
}

fn getFADT(rsdp: *RSDP) !*SDTHeader {
    const rsdt = rsdp.rsdt_address;
    const enteries = rsdt.h.length - @sizeOf(SDTHeader) / @sizeOf(u32);
    var index = rsdt.entries;
    while (index <= rsdt.entries + enteries) : (index += 1) {
        const header: *SDTHeader = @ptrFromInt(index);
        if (header.signature == FADT_SIGNATURE) {
            return header;
        }
    }
    return acpiErrors.NotFound;
}
