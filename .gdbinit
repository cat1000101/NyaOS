target remote localhost:1234
file ./zig-out/extra/kernel.elf

lay src

b kmain
continue
