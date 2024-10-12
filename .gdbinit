# Connect to the remote QEMU instance
target remote localhost:1234

# Load the ELF file automatically
file ./zig-out/extra/kernel.elf

set pagination off

lay src

# Optionally set breakpoints
b kmain

# Optionally start the program
continue
