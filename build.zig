const std = @import("std");
const print = std.debug.print;
const Builder = std.Build;
const Target = std.Target;
const Feature = std.Target.Cpu.Feature;

pub fn build(b: *Builder) void {
    // building the kernel into a kernel.elf
    const kernel_dep = b.dependency("kernel", .{});

    const kernel_exe = kernel_dep.artifact("kernel.elf");
    const kernel_exe_step = &b.addInstallArtifact(kernel_exe, .{
        .dest_dir = .{
            .override = .{
                .custom = "/extra/",
            },
        },
    }).step;
    b.getInstallStep().dependOn(kernel_exe_step);

    // setting the paths and commands
    const kernel_path = kernel_exe.getEmittedBin();
    const grub_path = b.path("bootloader/grub.cfg");
    const kernel_sys = b.fmt("sysroot/boot/{s}", .{kernel_exe.out_filename});
    const grub_sys = b.fmt("sysroot/boot/grub/{s}", .{"grub.cfg"});
    const iso_cmd = [_][]const u8{ "grub2-mkrescue", "-o" };
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
    _ = wf.addCopyFile(grub_path, grub_sys);

    // making the iso
    const mkiso = b.addSystemCommand(&iso_cmd);
    const nyaos_iso_file = mkiso.addOutputFileArg("NyaOS.iso");
    mkiso.addDirectoryArg(wf.getDirectory().path(b, "sysroot"));

    const install_iso = &b.addInstallFileWithDir(nyaos_iso_file, .prefix, "NyaOS.iso").step;
    nyaos_iso_file.addStepDependencies(install_iso);
    install_iso.dependOn(kernel_exe_step);

    // step to make everything
    const all_step = b.step("all", "does(installs) everything");
    const steps: []const *std.Build.Step = &.{ install_iso, kernel_exe_step };
    for (steps) |step| all_step.dependOn(step);

    // step and commands to run the iso in qemu
    const run_cmd_args = [_][]const u8{"qemu-system-i386"} ++ common_qemu_args;
    const run_cmd = b.addSystemCommand(&run_cmd_args);
    run_cmd.addArg("-cdrom");
    run_cmd.addFileArg(nyaos_iso_file);
    run_cmd.step.dependOn(install_iso);

    // step and commands to run the iso in qemu
    const debug_cmd_args = [_][]const u8{"qemu-system-i386"} ++ common_qemu_args;
    const debug_cmd = b.addSystemCommand(&debug_cmd_args);
    debug_cmd.addArg("-s");
    debug_cmd.addArg("-S");
    debug_cmd.addArg("-kernel");
    debug_cmd.addFileArg(kernel_path);
    debug_cmd.step.dependOn(kernel_exe_step);

    const debug_step = b.step("debug", "debugs the kernel with qemu");
    debug_step.dependOn(&debug_cmd.step);

    const run_step = b.step("run", "runs the iso file with qemu");
    run_step.dependOn(&run_cmd.step);
}
