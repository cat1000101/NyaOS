ENTRY(_start)
 
SECTIONS {
    . = 2M;

    kernel_physical_start = .;
 
    .multiboot : {
        KEEP(*(.multiboot))
    }

    .boot ALIGN(4K): {
        *(.boot)
    }

    . += 0xC0000000;

    kernel_start = .;

    kernel_text_start = .;
    .text ALIGN(4K):AT(ADDR(.text) - 0xC0000000) {
        *(.text)
    }
    kernel_text_end = .;
 
    kernel_rodata_start = .;
    .rodata ALIGN(4K):AT(ADDR(.rodata) - 0xC0000000) {
        *(.rodata)
    }
    kernel_rodata_end = .;
 
    kernel_data_start = .;
    .data ALIGN(4K):AT(ADDR(.data) - 0xC0000000) {
        *(.data)
    }
    kernel_data_end = .;
 
    kernel_bss_start = .;
    .bss ALIGN(4K):AT(ADDR(.bss) - 0xC0000000) {
        *(COMMON)
        *(.bss)
    }
    kernel_bss_end = .;
    
    kernel_end = .;
    kernel_physical_end = . - 0xC0000000;
}