const std = @import("std");
const Builder = std.Build;
const Target = std.Target;
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

    const target = b.resolveTargetQuery(Target.Query{
        .cpu_arch = Target.Cpu.Arch.x86,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
        .cpu_features_sub = disabled_features,
        .cpu_features_add = enabled_features,
    });

    // const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });

    const kernelModule = b.createModule(.{
        .optimize = .Debug,
        .strip = false,
        .target = target,
        .root_source_file = b.path("src/main.zig"),
        .code_model = .kernel,
    });

    const kernel_exe = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = kernelModule,
    });

    kernel_exe.root_module.addImport("kernel", kernelModule);

    kernel_exe.setLinkerScript(b.path("src/arch/x86/linker.ld"));

    b.installArtifact(kernel_exe);
}
