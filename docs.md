# NyaOS Documentation
More of an explanation of things in short and how I do them

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

---

## Boot Process  
The kernel is compiled to ELF format.  
Using it and any necessary files, we make a sysroot. In it we have `/boot` with the kernel image, and a `/boot/grub` folder with GRUB-related stuff. Finally, we use `grub-mkrescue` to make the image.

We use the Multiboot 2 spec, and the entry point from the bootloader is `_start`.  
When handed off from the bootloader, we need to do a few things so the kernel can actually run:  
First, we load a temporary page directory with the higher half kernel and the BIOS mapped.  
Then we set the stack pointer using a buffer we made and call `kmain`, which is the main entry point of the higher half kernel.

---

## Kernel Structure  
The kernel "starts" at `kmain`.  
We begin by checking the Multiboot header, then enabling and initializing the GDT and IDT.  
After that, we get the memory map from the bootloader for the PMM and initialize the physical page allocator.  
We do the same for the VMM, but first we replace the temporary page table (Page Directory) with a new one in higher-half kernel memory mapping.  
We set some necessary page tables like the higher-half kernel page table and BIOS identity map, then enable it, making the VMM allocator usable.

After that, we initialize the VGA driver (which only just prints the logo to the screen),  
enable ACPI and PS/2 so that pressing keys on the keyboard shows output on VGA/TTY and QEMU debug output.

At the end, we loop infinitely.

---

## Memory Management  
We have two important components in memory management: PMM and VMM. Both use a basic bitmap allocator for page allocation.

- The PMM bitmap allocator only returns an address that has `n` pages free (unowned).  
- To actually use those pages, we go through the VMM bitmap allocator.  
- The VMM bitmap allocator keeps track of virtual memory and owned pages.  
When we want a new usable page, we call the VMM allocator. It tries to find a free virtual page, calls the PMM allocator to get a physical page, maps the two to each other, and returns it.

The memory structure looks like this:
### Physical  
```
0x00000000  ..  0x00100000                  - 1MiB BIOS  
0x00200000  ..  0x00200000 + kernel_size    - Kernel physical address space  

ACPI_Tables ..  before_ram_end              - ACPI tables (reclaimable) 
ram_end     ..  ram_size * 2                - Memory-mapped stuff 
Other non-type 1 memory mappings from bootloader  
```
[ACPI spec](https://uefi.org/sites/default/files/resources/ACPI_6_3_final_Jan30.pdf#page=880)  

### Virtual  
```
0x00000000  ..  0x00100000                  - ID-mapped BIOS (1MiB)  
0xC0000000  ..  0xC0100000                  - BIOS mapped to higher half (1MiB)  
0xC0200000  ..  (0xC0200000 + kernel_size)  - Kernel mapped to higher half (~4MiB)  
0xC0000000  ..  0xFFC00000                  - Kernel memory (~1GiB)  
0xFFC00000  ..  0xFFFFFFFF                  - Recursive paging map (4MiB)

ACPI_Tables ..  before_ram_end              - ACPI tables (reclaimable)  
ram_end     ..  ram_size * 2                - Memory-mapped stuff  
Other non-type 1 memory mappings from bootloader are identity-mapped  
```
[ACPI spec](https://uefi.org/sites/default/files/resources/ACPI_6_3_final_Jan30.pdf#page=880)  

---

## Interrupt Handling  
Exception interrupts are all generated with a `push` of the interrupt number and a call to a common handler.  
The PIC is remapped to 0x20, so IRQs start from interrupt 0x20.  
There’s a function that generates wrappers for handlers so they don’t need to worry about prelude/postlude code and still get the CPU state.

---

## Drivers  
- **VGA driver** uses the BIOS VGA memory at `0xB8000`.  
- **Keyboard driver** uses PS/2. It doesn’t store which keys are pressed; it just prints the key to debug output and TTY.  
- **ACPI driver** is very minimal and only gets the FADT and RSDP/RSDT.

---