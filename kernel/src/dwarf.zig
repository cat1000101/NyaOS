const std = @import("std");
const log = std.log;
const elf = @import("drivers/elf.zig");
const debug = @import("arch/x86/debug.zig");

// stolen from https://github.com/xor-bits/hiillos which stole from std and adapted
const sourceFilesList = @import("sources");
pub const SourceFile = struct {
    path: []const u8,
    contents: []const u8,
};
pub const sourceFiles: [sourceFilesList.sources.len]SourceFile = b: {
    var files: [sourceFilesList.sources.len]SourceFile = undefined;
    for (sourceFilesList.sources, 0..) |path, i| {
        files[i] = .{
            .path = path,
            .contents = @embedFile(path),
        };
    }
    break :b files;
};

pub fn getSelfDwarf(
    allocator: std.mem.Allocator,
    elf_bin: []const u8,
) !std.debug.Dwarf {
    const header = try elf.getElf32Ehdr(elf_bin);

    var sections = std.debug.Dwarf.null_section_array;

    for (elf.getShdrSlice(header)) |shdr| {
        const name = elf.getStrFromStrTable(header, shdr.name).?;
        // std.log.debug("getSelfDwarf:  shdr: {s}\n", .{name});

        if (std.mem.eql(u8, name, ".debug_info")) {
            sections[@intFromEnum(std.debug.Dwarf.Section.Id.debug_info)] = .{
                .data = elf.getSectionData(header, shdr),
                .owned = false,
            };
        } else if (std.mem.eql(u8, name, ".debug_abbrev")) {
            sections[@intFromEnum(std.debug.Dwarf.Section.Id.debug_abbrev)] = .{
                .data = elf.getSectionData(header, shdr),
                .owned = false,
            };
        } else if (std.mem.eql(u8, name, ".debug_str")) {
            sections[@intFromEnum(std.debug.Dwarf.Section.Id.debug_str)] = .{
                .data = elf.getSectionData(header, shdr),
                .owned = false,
            };
        } else if (std.mem.eql(u8, name, ".debug_line")) {
            sections[@intFromEnum(std.debug.Dwarf.Section.Id.debug_line)] = .{
                .data = elf.getSectionData(header, shdr),
                .owned = false,
            };
        } else if (std.mem.eql(u8, name, ".debug_ranges")) {
            sections[@intFromEnum(std.debug.Dwarf.Section.Id.debug_ranges)] = .{
                .data = elf.getSectionData(header, shdr),
                .owned = false,
            };
        } else if (std.mem.eql(u8, name, ".eh_frame")) {
            sections[@intFromEnum(std.debug.Dwarf.Section.Id.eh_frame)] = .{
                .data = elf.getSectionData(header, shdr),
                .owned = false,
            };
        } else if (std.mem.eql(u8, name, ".eh_frame_hdr")) {
            sections[@intFromEnum(std.debug.Dwarf.Section.Id.eh_frame_hdr)] = .{
                .data = elf.getSectionData(header, shdr),
                .owned = false,
            };
        }
    }

    var dwarf: std.debug.Dwarf = .{
        .endian = .little,
        .sections = sections,
        .is_macho = false,
    };

    log.debug("sections: {any}\n", .{sections});

    try dwarf.open(allocator);
    return dwarf;
}

pub fn printSourceAtAddress(
    allocator: std.mem.Allocator,
    debug_info: *std.debug.Dwarf,
    address: usize,
    sources: []const SourceFile,
) !void {
    const sym = debug_info.getSymbol(allocator, address) catch {
        log.err("\x1B[90m0x{x}\x1B[0m\n", .{address});
        return;
    };
    defer if (sym.source_location) |loc| allocator.free(loc.file_name);

    log.err("\x1B[1m", .{});

    if (sym.source_location) |*sl| {
        log.err(
            "{s}:{d}:{d}",
            .{ sl.file_name, sl.line, sl.column },
        );
    } else {
        log.err("???:?:?", .{});
    }

    log.err(
        "\x1B[0m: \x1B[90m0x{x} in {s} ({s})\x1B[0m\n",
        .{ address, sym.name, sym.compile_unit_name },
    );

    // std.debug.printSourceAtAddress(debug_info: *SelfInfo, out_stream: anytype, address: usize, tty_config: io.tty.Config)

    const loc = sym.source_location orelse return;
    const source_file = findSourceFile(loc.file_name, sources) orelse return;

    var source_line: []const u8 = "<out-of-bounds>";
    var lines_iter = std.mem.splitScalar(u8, source_file.contents, '\n');
    for (0..@intCast(loc.line)) |_| {
        source_line = lines_iter.next() orelse "<out-of-bounds>";
    }

    log.err("{s}\n", .{source_line});

    const space_needed = @as(usize, @intCast(@max(loc.column, 1) - 1));

    try debug.writer.writeByteNTimes(' ', space_needed);
    log.err("\x1B[92m^\x1B[0m\n", .{});
}

pub fn findSourceFile(
    path: []const u8,
    sources: []const SourceFile,
) ?SourceFile {
    for_loop: for (sources) |s| {
        // b path is a full absolute path,
        // while a is relative to the git repo

        var a = std.fs.path.componentIterator(s.path) catch
            continue;
        var b = std.fs.path.componentIterator(path) catch
            continue;

        const a_last = a.last() orelse continue;
        const b_last = b.last() orelse continue;

        if (!std.mem.eql(u8, a_last.name, b_last.name)) continue;

        while (a.previous()) |a_part| {
            const b_part = b.previous() orelse continue :for_loop;
            if (!std.mem.eql(u8, a_part.name, b_part.name)) continue :for_loop;
        }

        return s;
    }

    return null;
}
