const std = @import("std");
const Builder = std.Build;
const Target = std.Target;
const Feature = std.Target.Cpu.Feature;

pub fn build(b: *Builder) !void {
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

    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });

    const kernelModule = b.createModule(.{
        .optimize = optimize,
        .target = target,
        .strip = false,
        .root_source_file = b.path("src/main.zig"),
        .code_model = .kernel,
    });

    kernelModule.addImport("sources", try generateSourcesZig(b));

    const kernel_exe = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = kernelModule,
    });

    kernel_exe.setLinkerScript(b.path("src/arch/x86/linker.ld"));

    b.installArtifact(kernel_exe);
}

fn appendSources(b: *std.Build, writer: anytype, sub_path: []const u8) !void {
    const dir_path = b.path(sub_path).getPath3(b, null);

    var dir = try dir_path.openDir("", .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(b.allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".zig")) continue;

        const file = try entry.dir.openFile(entry.basename, .{});
        defer file.close();

        try writer.print(
            \\    "{s}",
            \\
        , .{entry.path});
    }
}

fn generateSourcesZig(b: *std.Build) !*std.Build.Module {
    // collect all kernel source files for the stack tracer

    var sources_zig_contents = try std.ArrayList(u8).initCapacity(b.allocator, 16);
    errdefer sources_zig_contents.deinit(b.allocator);

    const sources_zig_writer = sources_zig_contents.writer(b.allocator);
    try sources_zig_writer.writeAll(
        \\pub const sources: []const []const u8 = &.{
        \\
    );
    try appendSources(b, sources_zig_writer, "src");
    try sources_zig_writer.writeAll(
        \\};
        \\
    );

    const kernel_source = b.addWriteFiles();
    const sources_zig = kernel_source.add(
        "sources.zig",
        sources_zig_contents.items,
    );

    return b.addModule("sources", .{
        .root_source_file = sources_zig,
    });
}
