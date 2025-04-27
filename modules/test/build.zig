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

    const userModule = b.createModule(.{
        .optimize = .Debug,
        .target = target,
        .root_source_file = b.path("src/testProgram.zig"),
        .code_model = .default, // may need to change this to something else
    });

    const userExe = b.addExecutable(.{
        .name = "program",
        .root_module = userModule,
    });

    userExe.setLinkerScript(b.path("src/linker.ld"));

    b.installArtifact(userExe);
}
