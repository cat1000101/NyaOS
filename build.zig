const std = @import("std");
const print = std.debug.print;
const Builder = std.Build;
const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;
const Feature = std.Target.Cpu.Feature;
// const disk_image_step = @import("disk-image-step");

pub fn build(b: *Builder) void {
    // building the kernel into a kernel.elf
    const kernel_dep = b.dependency("kernel", .{});
    const kernel = kernel_dep.artifact("kernel.elf");
    const kernel_step = b.addInstallArtifact(kernel, .{ .dest_dir = .{ .override = .{ .custom = "/extra/" } } });

    // setting the paths and commands
    const kernel_path = kernel.getEmittedBin();
    const grub_path = b.path("src/boot/grub.cfg");
    const kernel_sys = b.fmt("sysroot/boot/{s}", .{kernel.out_filename});
    const grub_sys = b.fmt("sysroot/boot/grub/{s}", .{"grub.cfg"});
    const iso_cmd = [_][]const u8{ "grub2-mkrescue", "-o" };
    const run_cmd = [_][]const u8{ "qemu-system-i386", "-machine", "q35", "-debugcon", "stdio", "-cdrom", "zig-out/NyaOS.iso" };
    const debug_cmd = [_][]const u8{ "qemu-system-i386", "-machine", "q35", "-d", "int", "-s", "-S", "-debugcon", "stdio", "-kernel", "zig-out/extra/kernel.elf" };

    // making sysroot directoy and putting the files there
    const wf = b.addWriteFiles();
    _ = wf.addCopyFile(kernel_path, kernel_sys);
    _ = wf.addCopyFile(grub_path, grub_sys);

    // making the iso
    const mkiso = b.addSystemCommand(&iso_cmd);
    mkiso.setCwd(wf.getDirectory());
    const out_file = mkiso.addOutputFileArg("NyaOS.iso");
    mkiso.addArgs(&.{"sysroot/"});

    const install_iso = b.addInstallFileWithDir(out_file, .prefix, "NyaOS.iso");

    // step to make everything
    const all_step = b.step("all", "does everything");
    const steps: []const *std.Build.Step = &.{ &kernel.step, &install_iso.step, &kernel_step.step };
    for (steps) |step| all_step.dependOn(step);

    // step and commands to run the iso in qemu
    const run = b.addSystemCommand(&run_cmd);
    run.step.dependOn(all_step);

    // step and commands to run the iso in qemu
    const debug = b.addSystemCommand(&debug_cmd);
    debug.step.dependOn(all_step);

    const debug_step = b.step("debug", "debugs the kernel with qemu");
    debug_step.dependOn(&debug.step);

    const run_step = b.step("run", "runs the iso file with qemu");
    run_step.dependOn(&run.step);
}
