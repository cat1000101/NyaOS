const std = @import("std");
const Builder = std.Build;
const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;
const Feature = std.Target.Cpu.Feature;
const kernel = @import("kernel");
const disk_image_step = @import("disk-image-step");

pub fn build(b: *Builder) void {
    kernel.build(b);
}
