const std = @import("std");
const Builder = std.Build;
const Target = std.Target;
const Feature = std.Target.Cpu.Feature;

pub fn getKernel(b: *Builder) struct {
    *std.Build.Step.Compile,
    *std.Build.Step,
} {
    const features = Target.x86.Feature;

    var disabled_features = Feature.Set.empty;
    var enabled_features = Feature.Set.empty;

    disabled_features.addFeature(@intFromEnum(features.mmx));
    disabled_features.addFeature(@intFromEnum(features.sse));
    disabled_features.addFeature(@intFromEnum(features.sse2));
    disabled_features.addFeature(@intFromEnum(features.avx));
    disabled_features.addFeature(@intFromEnum(features.avx2));
    enabled_features.addFeature(@intFromEnum(features.soft_float));

    const target_query = Target.Query{
        .cpu_arch = Target.Cpu.Arch.x86,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
        .cpu_features_sub = disabled_features,
        .cpu_features_add = enabled_features,
    };

    // const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_source_file = b.path("src/kernel/main.zig"),
        .target = b.resolveTargetQuery(target_query),
        .optimize = .Debug,
        .code_model = .kernel,
    });

    kernel.setLinkerScript(b.path("src/kernel/arch/x86/linker.ld"));

    const kernel_step = b.step("kernel", "Build the kernel");
    kernel_step.dependOn(&b.addInstallArtifact(kernel, .{ .dest_dir = .{
        .override = .{
            .custom = "/extra/",
        },
    } }).step);

    b.getInstallStep().dependOn(kernel_step);

    return .{ kernel, kernel_step };
}
