# Makefile for assembling boot.asm and kernel.asm with NASM

CC=zig cc -target x86-freestanding
CXX=zig c++ -target x86-freestanding
NASM=nasm
NASMFLAGS=-felf32
CFLAGS=-std=gnu99 -ffreestanding -O2 -Wall -Wextra

all: myos.bin

boot.o: boot.asm
	$(NASM) $(NASMFLAGS) $< -o $@

kernel.o: kernel.c
	$(CC) $(CFLAGS) -c $< -o $@

myos.bin: boot.o kernel.o
	gcc -m32 -T linker.ld -o myos.bin -ffreestanding -O2 -nostdlib boot.o kernel.o -lgcc

clean:
	rm -f boot.o kernel.o myos.bin
