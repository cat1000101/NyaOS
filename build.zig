const std = @import("std");
const print = std.debug.print;
const Builder = std.Build;
const Target = std.Target;
const Feature = std.Target.Cpu.Feature;
const kernelBuild = @import("src/kernel/build.zig");

pub fn build(b: *Builder) void {
    // building the kernel into a kernel.elf

    const kernel, const kernel_artifact_step = kernelBuild.getKernel(b);

    // setting the paths and commands
    const kernel_path = kernel.getEmittedBin();
    const grub_path = b.path("src/boot/grub.cfg");
    const kernel_sys = b.fmt("sysroot/boot/{s}", .{kernel.out_filename});
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
        "guest_errors,int,pcall,strace",
        "-D",
        "qemu.log",
        "-debugcon",
        "stdio",
    };
    const run_cmd = [_][]const u8{"qemu-system-i386"} ++ common_qemu_args ++ .{ "-cdrom", "zig-out/NyaOS.iso" };
    const debug_cmd = [_][]const u8{"qemu-system-i386"} ++ common_qemu_args ++ .{ "-s", "-S", "-kernel", "zig-out/extra/kernel.elf" };

    const kernel_step = b.step("kernel", "Build the kernel");
    kernel_step.dependOn(kernel_artifact_step);

    // making sysroot directoy and putting the files there
    const wf = b.addWriteFiles();
    _ = wf.addCopyFile(kernel_path, kernel_sys);
    _ = wf.addCopyFile(grub_path, grub_sys);

    // making the iso
    const mkiso = b.addSystemCommand(&iso_cmd);
    mkiso.setCwd(wf.getDirectory());
    const out_file = mkiso.addOutputFileArg("NyaOS.iso");
    mkiso.addArgs(&.{"sysroot/"});

    const install_iso = &b.addInstallFileWithDir(out_file, .prefix, "NyaOS.iso").step;
    install_iso.dependOn(&wf.step);
    install_iso.dependOn(kernel_step);

    // step to make everything
    const all_step = b.step("all", "does(installs) everything");
    const steps: []const *std.Build.Step = &.{ install_iso, kernel_step };
    for (steps) |step| all_step.dependOn(step);

    // step and commands to run the iso in qemu
    const run = &b.addSystemCommand(&run_cmd).step;
    run.dependOn(install_iso);

    // step and commands to run the iso in qemu
    const debug = &b.addSystemCommand(&debug_cmd).step;
    debug.dependOn(kernel_step);

    const debug_step = b.step("debug", "debugs the kernel with qemu");
    debug_step.dependOn(debug);

    const run_step = b.step("run", "runs the iso file with qemu");
    run_step.dependOn(run);
}
