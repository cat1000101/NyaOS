const std = @import("std");
const Builder = std.Build;
const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;
const Feature = std.Target.Cpu.Feature;
const disk_image_step = @import("disk-image-step");

pub fn build(b: *Builder) void {
    const kernel_dep = b.dependency("kernel", .{});
    const kernel = kernel_dep.artifact("kernel.elf");
    b.installArtifact(kernel);
    const kernel_path = kernel.getEmittedBin();

    const disk_image_dep = b.dependency("disk-image-step", .{});

    var rootfs = disk_image_step.FileSystemBuilder.init(b);
    rootfs.mkdir("boot/grub");
    rootfs.addFile(b.path("../../src/boot/grub.cfg"), "boot/grub");
    rootfs.addFile(kernel_path, "boot");

    const disk = disk_image_step.initializeDisk(disk_image_dep, 500 * disk_image_step.MiB, .{
        .mbr = .{
            .partitions = .{
                &.{
                    .type = .fat32_lba,
                    .bootable = true,
                    .size = 499 * disk_image_step.MiB,
                    .data = .{ .fs = rootfs.finalize(.{ .format = .fat32, .label = "NyaOS" }) },
                },
                null,
                null,
                null,
            },
        },
    });
    _ = disk; // autofix
}
