const virtio = @import("arch/x86/virtio.zig");
const tty = @import("drivers/tty.zig");

pub const MULTIBOOT_HEADER: u32 = 1;
pub const MULTIBOOT_SEARCH: u32 = 8192;
pub const MULTIBOOT_HEADER_ALIGN: u32 = 4;
pub const MULTIBOOT_HEADER_MAGIC: u32 = 0x1BADB002;
pub const MULTIBOOT_BOOTLOADER_MAGIC: u32 = 0x2BADB002;
pub const MULTIBOOT_MOD_ALIGN: u32 = 0x00001000;
pub const MULTIBOOT_INFO_ALIGN: u32 = 0x00000004;
pub const MULTIBOOT_PAGE_ALIGN: u32 = 0x00000001;
pub const MULTIBOOT_MEMORY_INFO: u32 = 0x00000002;
pub const MULTIBOOT_VIDEO_MODE: u32 = 0x00000004;
pub const MULTIBOOT_AOUT_KLUDGE: u32 = 0x00010000;
pub const MULTIBOOT_INFO_MEMORY: u32 = 0x00000001;
pub const MULTIBOOT_INFO_BOOTDEV: u32 = 0x00000002;
pub const MULTIBOOT_INFO_CMDLINE: u32 = 0x00000004;
pub const MULTIBOOT_INFO_MODS: u32 = 0x00000008;
pub const MULTIBOOT_INFO_AOUT_SYMS: u32 = 0x00000010;
pub const MULTIBOOT_INFO_ELF_SHDR: u32 = 0x00000020;
pub const MULTIBOOT_INFO_MEM_MAP: u32 = 0x00000040;
pub const MULTIBOOT_INFO_DRIVE_INFO: u32 = 0x00000080;
pub const MULTIBOOT_INFO_CONFIG_TABLE: u32 = 0x00000100;
pub const MULTIBOOT_INFO_BOOT_LOADER_NAME: u32 = 0x00000200;
pub const MULTIBOOT_INFO_APM_TABLE: u32 = 0x00000400;
pub const MULTIBOOT_INFO_VBE_INFO: u32 = 0x00000800;
pub const MULTIBOOT_INFO_FRAMEBUFFER_INFO: u32 = 0x00001000;
pub const MULTIBOOT_FRAMEBUFFER_TYPE_INDEXED: u32 = 0;
pub const MULTIBOOT_FRAMEBUFFER_TYPE_RGB: u32 = 1;
pub const MULTIBOOT_FRAMEBUFFER_TYPE_EGA_TEXT: u32 = 2;
pub const MULTIBOOT_MEMORY_AVAILABLE: u32 = 1;
pub const MULTIBOOT_MEMORY_RESERVED: u32 = 2;
pub const MULTIBOOT_MEMORY_ACPI_RECLAIMABLE: u32 = 3;
pub const MULTIBOOT_MEMORY_NVS: u32 = 4;
pub const MULTIBOOT_MEMORY_BADRAM: u32 = 5;

pub const multiboot_header = extern struct {
    magic: u32 = 0,
    flags: u32 = 0,
    checksum: u32 = 0,
    header_addr: u32 = 0,
    load_addr: u32 = 0,
    load_end_addr: u32 = 0,
    bss_end_addr: u32 = 0,
    entry_addr: u32 = 0,
    mode_type: u32 = 0,
    width: u32 = 0,
    height: u32 = 0,
    depth: u32 = 0,
};

pub const multiboot_aout_symbol_table = extern struct {
    tabsize: u32 = 0,
    strsize: u32 = 0,
    addr: u32 = 0,
    reserved: u32 = 0,
};

pub const multiboot_elf_section_header_table = extern struct {
    num: u32 = 0,
    size: u32 = 0,
    addr: u32 = 0,
    shndx: u32 = 0,
};

const union_unnamed_1 = extern union {
    aout_sym: multiboot_aout_symbol_table,
    elf_sec: multiboot_elf_section_header_table,
};

const unnamed_3 = extern struct {
    framebuffer_palette_addr: u32 = 0,
    framebuffer_palette_num_colors: u16 = 0,
};

const unnamed_4 = extern struct {
    framebuffer_red_field_position: u8 = 0,
    framebuffer_red_mask_size: u8 = 0,
    framebuffer_green_field_position: u8 = 0,
    framebuffer_green_mask_size: u8 = 0,
    framebuffer_blue_field_position: u8 = 0,
    framebuffer_blue_mask_size: u8 = 0,
};

const union_unnamed_2 = extern union {
    unnamed_0: unnamed_3,
    unnamed_1: unnamed_4,
};

pub const multiboot_info = extern struct {
    flags: u32 = 0,
    mem_lower: u32 = 0,
    mem_upper: u32 = 0,
    boot_device: u32 = 0,
    cmdline: u32 = 0,
    mods_count: u32 = 0,
    mods_addr: u32 = 0,
    u: union_unnamed_1 = 0,
    mmap_length: u32 = 0,
    mmap_addr: u32 = 0,
    drives_length: u32 = 0,
    drives_addr: u32 = 0,
    config_table: u32 = 0,
    boot_loader_name: u32 = 0,
    apm_table: u32 = 0,
    vbe_control_info: u32 = 0,
    vbe_mode_info: u32 = 0,
    vbe_mode: u16 = 0,
    vbe_interface_seg: u16 = 0,
    vbe_interface_off: u16 = 0,
    vbe_interface_len: u16 = 0,
    framebuffer_addr: u64 = 0,
    framebuffer_pitch: u32 = 0,
    framebuffer_width: u32 = 0,
    framebuffer_height: u32 = 0,
    framebuffer_bpp: u8 = 0,
    framebuffer_type: u8 = 0,
    unnamed_0: union_unnamed_2 = 0,
};

pub const multiboot_color = extern struct {
    red: u8 = 0,
    green: u8 = 0,
    blue: u8 = 0,
};

pub const multiboot_mmap_entry = extern struct {
    size: u32 align(1) = 0,
    addr: u64 align(1) = 0,
    len: u64 align(1) = 0,
    type: u32 align(1) = 0,
};

pub const multiboot_mod_list = extern struct {
    mod_start: u32 = 0,
    mod_end: u32 = 0,
    cmdline: u32 = 0,
    pad: u32 = 0,
};

pub const multiboot_apm_info = extern struct {
    version: u16 = 0,
    cseg: u16 = 0,
    offset: u32 = 0,
    cseg_16: u16 = 0,
    dseg: u16 = 0,
    flags: u16 = 0,
    cseg_len: u16 = 0,
    cseg_16_len: u16 = 0,
    dseg_len: u16 = 0,
};

pub fn checkMultibootHeader(header: *multiboot_info, magic: u32) bool {
    if (magic != MULTIBOOT_BOOTLOADER_MAGIC) {
        virtio.printf("Invalid magic number: {d}\n", .{magic});
        return false;
    }
    if (header.flags >> 6 & 1 == 0) {
        virtio.printf("No memory map provided by GRUB sad\n", .{});
        return false;
    }
    const mmm: [*]multiboot_mmap_entry = @ptrFromInt(header.mmap_addr);
    for (mmm, 0..(header.mmap_length / @sizeOf(multiboot_mmap_entry))) |entry, i| {
        virtio.printf(
            "Memory map entry {d}: size: 0x{x} address: 0x{x} len: 0x{x} type: 0x{x}\n",
            .{
                i,
                entry.size,
                entry.addr,
                entry.len,
                entry.type,
            },
        );
    }
    return true;
}
