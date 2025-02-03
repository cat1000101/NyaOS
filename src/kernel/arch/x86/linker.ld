ENTRY(_start)
 
SECTIONS {
    . = 2M;

    kernel_start = .;
 
    .multiboot : {
        KEEP(*(.multiboot))
    }

    kernel_text_start = .;
    .text : ALIGN(4K) {
        *(.text)
    }
    kernel_text_end = .;
 
    kernel_rodata_start = .;
    .rodata : ALIGN(4K) {
        *(.rodata)
    }
    kernel_rodata_end = .;
 
    kernel_data_start = .;
    .data : ALIGN(4K) {
        *(.data)
    }
    kernel_data_end = .;
 
    kernel_bss_start = .;
    .bss : ALIGN(4K) {
        *(COMMON)
        *(.bss)
    }
    kernel_bss_end = .;

    kernel_end = .;
}