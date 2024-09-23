pub const bootInfoStruct = packed struct {
    flags: u32, //            |    (required)
    mem_lower: u32, //        |    (present if flags[0] is set)
    mem_upper: u32, //        |    (present if flags[0] is set)

    boot_device: u32, //      |    (present if flags[1] is set)

    cmdline: u32, //          |    (present if flags[2] is set)

    mods_count: u32, //       |    (present if flags[3] is set)
    mods_addr: u32, //        |    (present if flags[3] is set)

    syms1: u32, //          |    (present if flags[4] or
    syms2: u32, //                        |                flags[5] is set)
    syms3: u32,
    syms4: u32,

    mmap_length: u32, //      |    (present if flags[6] is set)
    mmap_addr: u32, //        |    (present if flags[6] is set)

    drives_length: u32, //    |    (present if flags[7] is set)
    drives_addr: u32, //      |    (present if flags[7] is set)

    config_table: u32, //     |    (present if flags[8] is set)

    boot_loader_name: u32, // |    (present if flags[9] is set)

    apm_table: u32, //        |    (present if flags[10] is set)

    vbe_control_info: u32, // |    (present if flags[11] is set)
    vbe_mode_info: u32, //    |
    vbe_mode: u16, //         |
    vbe_interface_seg: u16, //|
    vbe_interface_off: u16, //|
    vbe_interface_len: u16, //|

    // 88      | framebuffer_addr  |    (present if flags[12] is set)
    // 96      | framebuffer_pitch |
    // 100     | framebuffer_width |
    // 104     | framebuffer_height|
    // 108     | framebuffer_bpp   |
    // 109     | framebuffer_type  |
    // 110-115 | color_info        |

};
