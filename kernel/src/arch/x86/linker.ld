ENTRY(_start)
 
SECTIONS {
    . = 2M;
 
    .multiboot : {
        KEEP(*(.multiboot))
    }

    .boot ALIGN(4K): {
        *(.boot)
    }

    . += 0xC0000000;


    .text ALIGN(4K):AT(ADDR(.text) - 0xC0000000) {
        kernel_start = .;
        kernel_text_start = .;
        *(.text)
        kernel_text_end = .;
    }
 
    .rodata ALIGN(4K):AT(ADDR(.rodata) - 0xC0000000) {
        kernel_rodata_start = .;
        *(.rodata)
        kernel_rodata_end = .;
    }
 
    .data ALIGN(4K):AT(ADDR(.data) - 0xC0000000) {
        kernel_data_start = .;
        *(.data)
        kernel_data_end = .;
    }
 
    .bss ALIGN(4K):AT(ADDR(.bss) - 0xC0000000) {
        kernel_bss_start = .;
        *(COMMON)
        *(.bss)
        kernel_bss_end = .;
        kernel_end = .;
    }
    
    kernel_physical_start = kernel_start - 0xC0000000;
    kernel_physical_end = kernel_end - 0xC0000000;

    kernel_size_in_4MIB_pages = (kernel_physical_end >> 22) - (kernel_physical_start >> 22);
    kernel_size_in_4KIB_pages = (kernel_physical_end >> 12) - (kernel_physical_start >> 12);
}