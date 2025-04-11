# NyaOS Documentation
more of explanation of things in short and how i do them

## Table of Contents
[Build Instructions](#build-instructions)  
[Boot Process](#boot-process)  
[Kernel Structure](#kernel-structure)  
[Memory Management](#memory-management)  
[Interrupt Handling](#interrupt-handling)  
[Drivers](#drivers)  

---

## Build Instructions
To build and run NyaOS, use:
```
zig build run
```
To build without running immediately, use:
```
zig build all
```

The ISO output is located in the `zig-out` directory. Ensure you have the following dependencies installed:
- grub2
- zig 0.14.0
- qemu (for running)
- xorriso

## Boot Process
The kernel is compiled to ELF format.
Using it and any necessary files, we make a sysroot. In it we have /boot with the kernel image, and a /boot/grub folder with GRUB-related stuff. Finally, we use grub-mkrescue to make the image.

We use the Multiboot 2 spec, and the entry point from the bootloader is _start.
When handed off from the bootloader, we need to do a few things so the kernel can actually run:
First, we load a temporary page directory with the higher half kernel and the BIOS mapped.
Then we set the stack pointer using a buffer we made and call kmain, which is the main entry point of the higher half kernel.

## Kernel Structure
the kernel "starts" at the kmain,
we start with checking the multiboot header then enabling and initialaizing the gdt and idt.
after that we get the memory map from the bootloader for the PMM and initialize the physical page allocator
we do the same for VMM but first we replace the temperary page table(Page Directory) with a new one that is in higher half kernel memory mapping and set some nessesary page tables like higher half kernel page table and bios id map and finally enable it making the VMM allocator usable.

after that we initalize the vga driver which only just prints the logo? to the screen
and enable acpi and ps/2 letting you press on the keyboard and it ill be printed to the vga/tty and qemu debug output.

and at the end we loop infinitly.

## Memory Management
we have two important components in memory managment PMM and VMM both have a basic bitmap allocator for page allocation,
the PMM bitmap allocator only returns an address that has N pages free from ownership and to make them usable we use the VMM bitmap allocator,
the VMM bitmap allocator also keeps track of owned pages and also can return address but he keeps track of the virtual memory.
when tring to get new usable page we call the VMM allocator and it in return tries to find free page then calls the PMM allocator to find usable ram to map the virtual page to physical one and finally returns it

the memory struction looks like this:
// how the virtual memory looks like:
// 0x00000000 - 0x00100000 - 1MiB  - id maped 1 to 1 - BIOS
// 0x00100000 - 0xC0000000 - 3GiB~ - RAM
// 0xC0000000 - 0xFFC00000 - 1GiB~ - Kernel space
// 0xFFC00000 - 0xFFFFFFFF - 4MIB  - recursive paging map

### Physical
0x00000000 - 0x00100000 - 1MiB - BIOS
0x00200000 - 0x00200000 + kernel_size - physical kernel address space

ACPI_Tables - before_ram_end - acpi tables that are reclaimable [acpi spec](https://uefi.org/sites/default/files/resources/ACPI_6_3_final_Jan30.pdf#page=880)
ram_end - ram_size * 2 - some memory mapped things [acpi spec](https://uefi.org/sites/default/files/resources/ACPI_6_3_final_Jan30.pdf#page=880)
and all other non type 1 memory mapping from bootloader

### Virtual
0x00000000 .. 0x00100000 - id mapped bios - 1MiB
0xC0000000 .. 0xC0100000 - bios mapped to higher half - 1MiB
0xC0200000 .. (0xC0200000 + kernel_size) - kernel mapped to higher half - 4MIB~
0xC0000000 .. 0xFFC00000 - kernel memory - 1GiB~
0xFFC00000 .. 0xFFFFFFFF - 4MIB  - recursive paging map

ACPI_Tables .. before_ram_end - acpi tables that are reclaimable [acpi spec](https://uefi.org/sites/default/files/resources/ACPI_6_3_final_Jan30.pdf#page=880)
ram_end .. ram_size * 2 - some memory mapped things [acpi spec](https://uefi.org/sites/default/files/resources/ACPI_6_3_final_Jan30.pdf#page=880)
and all other non type 1 memory mapping from bootloader are id mapped

## Interrupt Handling
exeption interrupts are all generated with push of the interrupt number and call common handler.
pic is remaped to 0x20 so irq start from interrupt 0x20.
there is a function that generates a wrapper for functions so they dont need to care about prelog and endlog and get cpu state.

## Drivers
vga driver uses the bios vga memory 0xB8000
keyboard driver uses ps/2 and corrently doesnt store what keys are pressed and only prints the key pressed to debug output and tty
acpi driver is very bare and only gets FADT and RSDP/RSDT

---