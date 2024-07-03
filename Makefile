# Makefile for assembling boot.asm and kernel.asm with NASM

CC=zig cc -target x86-freestanding
CXX=zig c++ -target x86-freestanding
CLANG=clang -m32
LINKER=/usr/local/i386elfgcc/bin/i386-elf-ld
LIBGCCPATH=/usr/local/i386elfgcc
NASM=nasm
NASMFLAGS=-felf32
CFLAGS=-std=gnu99 -ffreestanding -Wall -Wextra
CFLAGUPTIMIZED=-std=gnu99 -ffreestanding -O2 -Wall -Wextra

all: myos.iso

boot.o: boot.asm
	$(NASM) $(NASMFLAGS) $< -o $@

kernel.o: kernel.c
	$(CC) $(CFLAGS) -c $< -o $@

myos.bin: boot.o kernel.o
	$(LINKER) -T linker.ld -o myos.bin boot.o kernel.o

myos.iso: myos.bin
	mkdir -p isodir/boot/grub
	cp myos.bin isodir/boot/myos.bin
	cp grub.cfg isodir/boot/grub/grub.cfg
	grub-mkrescue -o myos.iso isodir

clean:
	rm -rf boot.o kernel.o myos.bin myos.iso isodir

run: myos.iso
	qemu-system-i386 -cdrom myos.iso