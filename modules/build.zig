const std = @import("std");
const Builder = std.Build;
const Target = std.Target;
const Feature = std.Target.Cpu.Feature;

pub fn build(b: *Builder) void {
    const runDoomgeneric = true;
    if (runDoomgeneric) {
        const doomgeneric_dep = b.dependency("doomgeneric", .{});
        const doomgeneric = doomgeneric_dep.artifact("program.elf");
        b.installArtifact(doomgeneric);
    } else {
        const testApp_dep = b.dependency("testApp", .{});
        const testApp = testApp_dep.artifact("program.elf");
        b.installArtifact(testApp);
    }
}
