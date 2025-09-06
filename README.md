# NyaOS
os that is stupid :3

## Welcome to NyaOS!

### Description
NyaOS is a passion project built with Zig that aims to be an oparating system that is safe... hopefully

### Roadmap
Currently working/TODO: fs, Shell/REPL

Completed: VGA output, debug tooling, GDT, IDT, PIC, ACPI, PS/2, PMM, VMM, VFS?, PIT, Syscalls, Port Doom

Extra: Scheduler, Apps

TODO (Maybe): APIC, VFS(complete one), 64-bit

### Build and Run Instructions
To build and run NyaOS, use: (if the build fails in the grub-mkrescue step then see `-Dgrub-mkrescue-fix` option in the help manu by running `zig build --help`)
```
zig build run
```
To build without running immediately, use:
```
zig build all
```

The ISO output is located in the `zig-out` directory. Ensure you have the following dependencies installed:
- grub2
- zig 0.15.1
- qemu (for running)
- xorriso

### License
NyaOS is licensed under the Cat Public License (CPL), or for the more formal, the MIT License.
