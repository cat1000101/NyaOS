const std = @import("std");
const print = std.debug.print;
const Builder = std.Build;

pub fn build(b: *Builder) void {
    // building executables from dependencies
    const kernel_dep = b.dependency("kernel", .{});
    const user_dep = b.dependency("apps", .{});

    const user_exe = user_dep.artifact("doomgeneric.elf");
    const doomgenericWadFile = user_dep.namedLazyPath("doom1.wad");
    const user_exe_step = &b.addInstallArtifact(user_exe, .{
        .dest_dir = .{
            .override = .{
                .custom = "extra/",
            },
        },
    }).step;
    const user_path = user_exe.getEmittedBin();
    b.getInstallStep().dependOn(user_exe_step);

    const kernel_exe = kernel_dep.artifact("kernel.elf");
    const kernel_exe_step = &b.addInstallArtifact(kernel_exe, .{
        .dest_dir = .{
            .override = .{
                .custom = "extra/",
            },
        },
    }).step;
    const kernel_path = kernel_exe.getEmittedBin();
    b.getInstallStep().dependOn(kernel_exe_step);

    // setting the paths and commands
    const grub_mkrescue = b.option(bool, "grub-mkrescue-fix", "some distros ship with grub2 named just grub this fixes the calling to grub2-mkrescue") orelse false;
    const grub_path = b.path("bootloader/grub.cfg");
    const kernel_sys = "sysroot/boot/kernel.elf";
    const user_modules_sys = "sysroot/modules/doomgeneric.elf";
    const doomgenericWadFile_sys = "sysroot/modules/doom1.wad";
    const grub_sys = "sysroot/boot/grub/grub.cfg";
    var iso_cmd: []const []const u8 = undefined;
    if (grub_mkrescue) {
        iso_cmd = &[_][]const u8{ "grub-mkrescue", "-o" };
    } else {
        iso_cmd = &[_][]const u8{ "grub2-mkrescue", "-o" };
    }
    const common_qemu_args = [_][]const u8{
        "-M",
        "q35", // add ,smm=off for smm spam off but vga not work? idk why ; -;
        "-m",
        "256M",
        "-no-reboot",
        "-no-shutdown",
        "-d",
        "guest_errors,int,mmu",
        "-D",
        ".extras/qemu.log",
        "-debugcon",
        "stdio",
    };

    // making sysroot directoy and putting the files there
    const wf = b.addWriteFiles();
    // const sysroot_path = wf.add(sub_path: []const u8, bytes: []const u8);
    _ = wf.addCopyFile(kernel_path, kernel_sys);
    _ = wf.addCopyFile(user_path, user_modules_sys);
    _ = wf.addCopyFile(doomgenericWadFile, doomgenericWadFile_sys);
    _ = wf.addCopyFile(grub_path, grub_sys);

    const sysroot_extra_step = &b.addInstallDirectory(.{
        .source_dir = wf.getDirectory().path(b, "sysroot"),
        .install_dir = .{ .custom = "extra" },
        .install_subdir = "sysroot",
    }).step;

    // making the iso
    const mkiso = b.addSystemCommand(iso_cmd);
    const nyaos_iso_file = mkiso.addOutputFileArg("NyaOS.iso");
    mkiso.addDirectoryArg(wf.getDirectory().path(b, "sysroot"));

    const install_iso = b.step("iso", "makes the iso");
    install_iso.dependOn(&b.addInstallFileWithDir(nyaos_iso_file, .prefix, "NyaOS.iso").step);
    install_iso.dependOn(kernel_exe_step);
    install_iso.dependOn(user_exe_step);
    install_iso.dependOn(sysroot_extra_step);

    // step and commands to run the iso in qemu
    const run_cmd_args = [_][]const u8{"qemu-system-i386"} ++ common_qemu_args;
    const run_cmd = b.addSystemCommand(&run_cmd_args);
    run_cmd.addArg("-cdrom");
    run_cmd.addFileArg(nyaos_iso_file);
    run_cmd.step.dependOn(install_iso);

    // step and commands to run the iso in bochs
    const debug_bochs_cmd_args = [_][]const u8{"bochs-debugger"};
    const debug_bochs_cmd = b.addSystemCommand(&debug_bochs_cmd_args);
    debug_bochs_cmd.addArg("-q");
    debug_bochs_cmd.addArg("-f");
    debug_bochs_cmd.addFileArg(b.path(".extras/bochsrc.txt")); // debug_symbols: file=zig-out/extra/kernel.elf
    debug_bochs_cmd.step.dependOn(install_iso);

    // step and commands to run the iso in qemu with debug and waiting for gdb connection
    const debug_cmd_args = [_][]const u8{"qemu-system-i386"} ++ common_qemu_args;
    const debug_cmd = b.addSystemCommand(&debug_cmd_args);
    debug_cmd.addArg("-s");
    debug_cmd.addArg("-S");
    debug_cmd.addArg("-cdrom");
    debug_cmd.addFileArg(nyaos_iso_file);
    debug_cmd.step.dependOn(install_iso);

    const debug_step = b.step("debug", "debugs the kernel with qemu");
    debug_step.dependOn(&debug_cmd.step);

    const debug_bochs_step = b.step("debug-bochs", "debugs the kernel with bochs");
    debug_bochs_step.dependOn(&debug_bochs_cmd.step);

    const run_step = b.step("run", "runs the iso file with qemu");
    run_step.dependOn(&run_cmd.step);
}
