const std = @import("std");
const Builder = std.Build;
const Target = std.Target;
const Feature = std.Target.Cpu.Feature;

pub fn build(b: *Builder) void {
    const testApp_dep = b.dependency("testApp", .{});
    const testApp = testApp_dep.artifact("testProgram.elf");
    b.installArtifact(testApp);

    const doomgeneric_dep = b.dependency("doomgeneric", .{});
    const doomgeneric = doomgeneric_dep.artifact("doomgeneric.elf");
    const doomgenericWadFile = doomgeneric_dep.namedLazyPath("doom1.wad");
    b.installArtifact(doomgeneric);
    b.addNamedLazyPath("doom1.wad", doomgenericWadFile);
}
