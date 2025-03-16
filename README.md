# NyaOS
os that is stupid :3

## Welcome to NyaOS!

### Description
NyaOS is a passion project built with Zig that aims to be an oparating system that is safe... hopefully

### Roadmap
Current: PMM, VMM, fs, Shell/REPL

Completed: VGA output, QEMU debug, GDB, printf, GDT, IDT, PIC, ACPI, PS/2

Extra: Syscalls, Scheduler, Apps, Port Doom

TODO (Maybe): PIT/timer, APIC, VFS, 64-bit

### Build and Run Instructions
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

### License
NyaOS is licensed under the Cat Public License (CPL), or for the more formal, the MIT License.
