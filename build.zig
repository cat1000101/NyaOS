const std = @import("std");
const Builder = std.Build;
const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;
const Feature = std.Target.Cpu.Feature;

pub fn build(b: *Builder) void {
    const features = Target.x86.Feature;

    var disabled_features = Feature.Set.empty;
    var enabled_features = Feature.Set.empty;

    disabled_features.addFeature(@intFromEnum(features.mmx));
    disabled_features.addFeature(@intFromEnum(features.sse));
    disabled_features.addFeature(@intFromEnum(features.sse2));
    disabled_features.addFeature(@intFromEnum(features.avx));
    disabled_features.addFeature(@intFromEnum(features.avx2));
    enabled_features.addFeature(@intFromEnum(features.soft_float));

    const target_query = .{
        .cpu_arch = Target.Cpu.Arch.x86,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
        .cpu_features_sub = disabled_features,
        .cpu_features_add = enabled_features,
    };

    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_source_file = b.path("src/boot/main.zig"),
        .target = b.resolveTargetQuery(target_query),
        .optimize = optimize,
        .code_model = .kernel,
    });
    kernel.setLinkerScript(b.path("src/kernel/arch/x86/linker.ld"));
    b.installArtifact(kernel);

    const kernel_step = b.step("kernel", "Build the kernel");
    kernel_step.dependOn(&kernel.step);

    const iso_dir = b.fmt("{s}/iso_root", .{b.cache_root.path orelse ""});
    const kernel_path = kernel.getEmittedBin().getDisplayName();
    const iso_path = b.fmt("{s}/disk.iso", .{b.exe_dir});

    const iso_cmd_str = &[_][]const u8{
        "/bin/sh",
        "-c",
        std.mem.concat(b.allocator, u8, &[_][]const u8{
            "mkdir -p ",
            iso_dir,
            " && ",
            "cp ",
            kernel_path,
            " ",
            iso_dir,
            " && ",
            "cp src/boot/grub.cfg ",
            iso_dir,
            " && ",
            "grub2-mkrescue -o ",
            iso_path,
            " ",
            iso_dir,
        }) catch unreachable,
    };

    const iso_cmd = b.addSystemCommand(iso_cmd_str);
    iso_cmd.step.dependOn(kernel_step);

    const iso_step = b.step("iso", "Build an ISO image");
    iso_step.dependOn(&iso_cmd.step);
    b.default_step.dependOn(iso_step);

    const run_cmd_str = &[_][]const u8{
        "qemu-system-x86_64",
        "-cdrom",
        iso_path,
        "-debugcon",
        "stdio",
        "-vga",
        "virtio",
        "-m",
        "4G",
        "-machine",
        "q35,accel=kvm:whpx:tcg",
        "-no-reboot",
        "-no-shutdown",
    };

    const run_cmd = b.addSystemCommand(run_cmd_str);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the kernel");
    run_step.dependOn(&run_cmd.step);
}
