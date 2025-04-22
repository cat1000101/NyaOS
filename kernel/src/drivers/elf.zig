const debug = @import("../arch/x86/debug.zig");

// ELF file format used https://refspecs.linuxfoundation.org/elf/elf.pdf spec

const Elf32Half = u16;
const Elf32Word = u32;
const Elf32Addr = u32;
const Elf32Off = u32;
const Elf32Sword = i32;

const Elf32Ehdr = extern struct {
    /// e_ident The initial bytes mark the file as an object file and provide machine-independent
    /// data with which to decode and interpret the file's contents.
    ident: ElfIdent,
    /// e_type This member identifies the object file type.
    type: ElfType,
    /// e_machine This member's value specifies the required architecture for an individual file.
    machine: ElfMachine,
    /// e_version The value 1 signifies the original file format; extensions will create new versions
    /// with higher numbers.
    version: Elf32Word,
    /// e_entry This member gives the virtual address to which the system first transfers control,
    /// thus starting the process. If the file has no associated entry point, this member holds
    /// zero.
    entry: Elf32Addr,
    /// e_phoff This member holds the program header table's file offset in bytes. If the file has no
    /// program header table, this member holds zero.
    phoff: Elf32Off,
    /// e_shoff This member holds the section header table's file offset in bytes. If the file has no
    /// section header table, this member holds zero
    shoff: Elf32Off,
    /// e_flags This member holds processor-specific flags associated with the file. Flag names
    /// take the form EF_machine_flag
    flags: Elf32Word,
    /// e_ehsize This member holds the ELF header's size in bytes.
    ehsize: Elf32Half,
    /// e_phentsize This member holds the size in bytes of one entry in the file's program header table;
    /// all entries are the same size
    phentsize: Elf32Half,
    /// e_phnum This member holds the number of entries in the program header table. Thus the
    /// product of e_phentsize and e_phnum gives the table's size in bytes. If a file
    /// has no program header table, e_phnum holds the value zero.
    phnum: Elf32Half,
    /// e_shentsize This member holds a section header's size in bytes. A section header is one entry
    /// in the section header table; all entries are the same size.
    shentsize: Elf32Half,
    /// e_shnum This member holds the number of entries in the section header table. Thus the
    /// product of e_shentsize and e_shnum gives the section header table's size in
    /// bytes. If a file has no section header table, e_shnum holds the value zero.
    shnum: Elf32Half,
    /// e_shstrndx This member holds the section header table index of the entry associated with the
    /// section name string table. If the file has no section name string table, this member
    /// holds the value SHN_UNDEF.
    shstrndx: Elf32Half,
};

const ElfIdent = extern struct {
    /// File identification correct one: 0x7f, 'E', 'L', 'F'
    mag: [4]u8,
    /// File class 1 = 32-bit, 2 = 64-bit
    class: u8,
    /// Data encoding ELFDATA2LSB(1) = little-endian, ELFDATA2MSB(2) = big-endian
    data: u8,
    /// File version
    version: u8,
    /// padding bytes
    /// This value marks the beginning of the unused bytes in e_ident. These
    /// bytes are reserved and set to zero; programs that read object files should
    /// ignore them. The value of EI_PAD will change in the future if currently
    /// unused bytes are given meanings.
    pad: [9]u8,
};

const ElfType = enum(Elf32Half) {
    /// No file type
    NONE = 0,
    /// Relocatable file
    REL = 1,
    /// Executable file
    EXEC = 2,
    /// Shared object file
    DYN = 3,
    /// Core file
    CORE = 4,
    /// Processor-specific
    LOPROC = 0xff00,
    /// Processor-specific
    HIPROC = 0xffff,
    /// idk not in the spec i used
    _,
};

const ElfMachine = enum(Elf32Half) {
    /// No machine
    EM_NONE = 0,
    /// AT&T WE 32100
    EM_M32 = 1,
    /// SPARC
    EM_SPARC = 2,
    /// Intel Architecture
    EM_386 = 3,
    /// Motorola 68000
    EM_68K = 4,
    /// Motorola 88000
    EM_88K = 5,
    /// Intel 80860
    EM_860 = 7,
    /// MIPS RS3000 Big-Endian
    EM_MIPS = 8,
    /// MIPS RS4000 Big-Endian
    EM_MIPS_RS4_BE = 10,
    /// Reserved for future use
    _,
};

const ElfSpecialSections = enum(Elf32Half) {
    /// SHN_UNDEF This value marks an undefined, missing, irrelevant, or otherwise
    /// meaningless section reference. For example, a symbol "defined'' relative to
    /// section number SHN_UNDEF is an undefined symbol.
    UNDEF = 0,
    /// SHN_LORESERVE This value specifies the lower bound of the range of reserved indexes.
    LORESERVE = 0xff00,
    /// SHN_LOPROC Values in this inclusive range are reserved for processor-specific semantics.
    LOPROC = 0xff00,
    /// SHN_HIPROC Values in this inclusive range are reserved for processor-specific semantics.
    HIPROC = 0xff1f,
    /// SHN_ABS This value specifies absolute values for the corresponding reference. For
    /// example, symbols defined relative to section number SHN_ABS have
    /// absolute values and are not affected by relocation.
    ABS = 0xfff1,
    /// SHN_COMMON Symbols defined relative to this section are common symbols, such as
    /// FORTRAN COMMON or unallocated C external variables.
    COMMON = 0xfff2,
    /// SHN_HIRESERVE This value specifies the upper bound of the range of reserved indexes. The
    /// system reserves indexes between SHN_LORESERVE and
    /// SHN_HIRESERVE, inclusive; the values do not reference the section header
    /// table.That is, the section header table does not contain entries for the
    /// reserved indexes.
    HIRESERVE = 0xffff,
    /// idk you are doing something wrong
    _,
};

const Elf32Shdr = extern struct {
    /// sh_name This member specifies the name of the section. Its value is an index into
    /// the section header string table section , giving
    /// the location of a null-terminated string.
    name: Elf32Word,
    /// sh_type This member categorizes the section's contents and semantics. Section
    /// types and their descriptions appear below.
    type: Elf32ShdrType,
    /// sh_flags Sections support 1-bit flags that describe miscellaneous attributes. Flag
    /// definitions appear below.
    flags: Elf32ShdrFlags,
    /// sh_addr If the section will appear in the memory image of a process, this member
    /// gives the address at which the section's first byte should reside. Otherwise,
    /// the member contains 0.
    addr: Elf32Addr,
    /// sh_offset This member's value gives the byte offset from the beginning of the file to
    /// the first byte in the section. One section type, SHT_NOBITS described
    /// below, occupies no space in the file, and its sh_offset member locates
    /// the conceptual placement in the file.
    offset: Elf32Off,
    /// sh_size This member gives the section's size in bytes. Unless the section type is
    /// SHT_NOBITS, the section occupies sh_size bytes in the file. A section
    /// of type SHT_NOBITS may have a non-zero size, but it occupies no space
    /// in the file.
    size: Elf32Word,
    /// sh_link This member holds a section header table index link, whose interpretation
    /// depends on the section type.
    link: Elf32Word,
    /// sh_info This member holds extra information, whose interpretation depends on the
    /// section type.
    info: Elf32Word,
    /// sh_addralign Some sections have address alignment constraints. For example, if a section
    /// holds a doubleword, the system must ensure doubleword alignment for the
    /// entire section. That is, the value of sh_addr must be congruent to 0,
    /// modulo the value of sh_addralign. Currently, only 0 and positive
    /// integral powers of two are allowed. Values 0 and 1 mean the section has no
    /// alignment constraints.
    addralign: Elf32Word,
    /// sh_entsize Some sections hold a table of fixed-size entries, such as a symbol table. For
    /// such a section, this member gives the size in bytes of each entry. The
    /// member contains 0 if the section does not hold a table of fixed-size entries.
    entsize: Elf32Word,
};

const Elf32ShdrType = enum(Elf32Word) {
    /// SHT_NULL This value marks the section header as inactive; it does not have an
    /// associated section. Other members of the section header have undefined
    /// values.
    NULL = 0,
    /// SHT_PROGBITS The section holds information defined by the program, whose format and
    /// meaning are determined solely by the program.
    PROGBITS = 1,
    /// SHT_SYMTAB holds a symbol table.
    SYMTAB = 2,
    /// SHT_STRTAB The section holds a string table.
    STRTAB = 3,
    /// SHT_RELA The section holds relocation entries with explicit addends, such as type
    /// Elf32_Rela for the 32-bit class of object files. An object file may have
    /// multiple relocation sections.
    RELA = 4,
    /// SHT_HASH The section holds a symbol hash table.
    HASH = 5,
    /// SHT_DYNAMIC The section holds information for dynamic linking.
    DYNAMIC = 6,
    /// SHT_NOTE This section holds information that marks the file in some way.
    NOTE = 7,
    /// SHT_NOBITS A section of this type occupies no space in the file but otherwise resembles
    /// SHT_PROGBITS. Although this section contains no bytes, the
    /// sh_offset member contains the conceptual file offset.
    NOBITS = 8,
    /// SHT_REL The section holds relocation entries without explicit addends, such as type
    /// Elf32_Rel for the 32-bit class of object files. An object file may have
    /// multiple relocation sections.
    REL = 9,
    /// SHT_SHLIB This section type is reserved but has unspecified semantics.
    SHLIB = 10,
    /// SHT_DYNSYM holds a symbol table.
    DYNSYM = 11,
    /// SHT_LOPROC Values in this inclusive range are reserved for processor-specific semantics.
    LOPROC = 0x70000000,
    /// SHT_HIPROC Values in this inclusive range are reserved for processor-specific semantics.
    HIPROC = 0x7fffffff,
    /// SHT_LOUSER This value specifies the lower bound of the range of indexes reserved for
    /// application programs.
    LOUSER = 0x80000000,
    /// SHT_HIUSER This value specifies the upper bound of the range of indexes reserved for
    /// application programs. Section types between SHT_LOUSER and
    /// SHT_HIUSER may be used by the application, without conflicting with
    /// current or future system-defined section types.
    HIUSER = 0xffffffff,
    /// idk this is weird one you found
    _,
};

const Elf32ShdrFlags = packed struct(Elf32Word) {
    /// SHF_WRITE The section contains data that should be writable during process execution.
    write: u1,
    /// SHF_ALLOC The section occupies memory during process execution. Some control
    /// sections do not reside in the memory image of an object file; this attribute
    /// is off for those sections.
    alloc: u1,
    /// SHF_EXECINSTR The section contains executable machine instructions.
    exec: u1,
    /// idk something that i dont know about
    pad: u25,
    /// SHF_MASKPROC All bits included in this mask are reserved for processor-specific semantics.
    mask: u4,
};

const Elf32Sym = extern struct {
    /// st_name This member holds an index into the object file's symbol string table, which holds
    /// the character representations of the symbol names.
    name: Elf32Word,
    /// st_value This member gives the value of the associated symbol. Depending on the context,
    /// this may be an absolute value, an address, and so on.
    value: Elf32Addr,
    /// st_size Many symbols have associated sizes. For example, a data object's size is the number
    /// of bytes contained in the object. This member holds 0 if the symbol has no size or
    /// an unknown size.
    size: Elf32Word,
    /// st_info This member specifies the symbol's type and binding attributes. A list of the values
    /// and meanings appears below.
    info: Elf32SymInfo,
    /// st_other This member currently holds 0 and has no defined meaning.
    other: u8,
    /// st_shndx Every symbol table entry is "defined'' in relation to some section; this member holds
    /// the relevant section header table index.
    /// some section indexes indicate special meanings.
    shndx: Elf32Half,
};

const Elf32SymInfo = packed struct(u8) {
    type: Elf32SymType,
    bind: Elf32SymBind,
};

const Elf32SymType = enum(u4) {
    /// STT_NOTYPE The symbol's type is not specified.
    NOTYPE = 0,
    /// STT_OBJECT The symbol is associated with a data object, such as a variable, an array,
    /// and so on.
    OBJECT = 1,
    /// STT_FUNC The symbol is associated with a function or other executable code.
    FUNC = 2,
    /// STT_SECTION The symbol is associated with a section. Symbol table entries of this type
    /// exist primarily for relocation and normally have STB_LOCAL binding.
    SECTION = 3,
    /// STT_FILE A file symbol has STB_LOCAL binding, its section index is SHN_ABS, and
    /// it precedes the other STB_LOCAL symbols for the file, if it is present.
    /// The symbols in ELF object files convey specific information to the linker and loader.
    FILE = 4,
    /// STT_LOPROC Values in this inclusive range are reserved for processor-specific semantics.
    /// If a symbol's value refers to a specific location within a section, its section
    /// index member, st_shndx, holds an index into the section header table.
    /// As the section moves during relocation, the symbol's value changes as well,
    /// and references to the symbol continue to "point'' to the same location in the
    /// program. Some special section index values give other semantics.
    LOPROC = 13,
    /// STT_HIPROC Values in this inclusive range are reserved for processor-specific semantics.
    /// If a symbol's value refers to a specific location within a section, its section
    /// index member, st_shndx, holds an index into the section header table.
    /// As the section moves during relocation, the symbol's value changes as well,
    /// and references to the symbol continue to "point'' to the same location in the
    /// program. Some special section index values give other semantics.
    HIPROC = 15,
    /// same
    _,
};

const Elf32SymBind = enum(u4) {
    /// STB_LOCAL Local symbols are not visible outside the object file containing their
    /// definition. Local symbols of the same name may exist in multiple files
    /// without interfering with each other.
    LOCAL = 0,
    /// STB_GLOBAL Global symbols are visible to all object files being combined. One file's
    /// definition of a global symbol will satisfy another file's undefined reference
    /// to the same global symbol.
    GLOBAL = 1,
    /// STB_WEAK Weak symbols resemble global symbols, but their definitions have lower
    /// precedence.
    WEAK = 2,
    /// STB_LOPROC Values in this inclusive range are reserved for processor-specific semantics.
    LOPROC = 13,
    /// STB_HIPROC Values in this inclusive range are reserved for processor-specific semantics.
    HIPROC = 15,
    /// same as usual idk what you did
    _,
};

const Elf32Phdr = extern struct {
    /// p_type This member tells what kind of segment this array element describes or how to
    /// interpret the array element's information. Type values and their meanings appear
    /// below.
    p_type: Elf32PhdrType,
    /// p_offset This member gives the offset from the beginning of the file at which the first byte
    /// of the segment resides.
    p_offset: Elf32Off,
    /// p_vaddr This member gives the virtual address at which the first byte of the segment resides
    /// in memory.
    p_vaddr: Elf32Addr,
    /// p_paddr On systems for which physical addressing is relevant, this member is reserved for
    /// the segment's physical address. This member requires operating system specific information.
    p_paddr: Elf32Addr,
    /// p_filesz This member gives the number of bytes in the file image of the segment; it may be
    /// zero.
    p_filesz: Elf32Word,
    /// p_memsz This member gives the number of bytes in the memory image of the segment; it
    /// may be zero.
    p_memsz: Elf32Word,
    /// p_flags This member gives flags relevant to the segment.
    p_flags: Elf32Word,
    /// p_align Loadable process segments must have congruent values for p_vaddr and
    /// p_offset, modulo the page size.This member gives the value to which the
    /// segments are aligned in memory and in the file. Values 0 and 1 mean that no
    /// alignment is required. Otherwise, p_align should be a positive, integral power of
    /// 2, and p_addr should equal p_offset, modulo p_align.
    p_align: Elf32Word,
};

const Elf32PhdrType = enum(Elf32Word) {
    /// PT_NULL The array element is unused; other members' values are undefined. This type lets
    /// the program header table have ignored entries.
    NULL = 0,
    /// PT_LOAD The array element specifies a loadable segment, described by p_filesz and
    /// p_memsz. The bytes from the file are mapped to the beginning of the memory
    /// segment. If the segment's memory size (p_memsz) is larger than the file size
    /// (p_filesz), the "extra'' bytes are defined to hold the value 0 and to follow the
    /// segment's initialized area. The file size may not be larger than the memory size.
    /// Loadable segment entries in the program header table appear in ascending order,
    /// sorted on the p_vaddr member.
    LOAD = 1,
    /// PT_DYNAMIC The array element specifies dynamic linking information.
    DYNAMIC = 2,
    /// PT_INTERP The array element specifies the location and size of a null-terminated path name to
    /// invoke as an interpreter.
    INTERP = 3,
    /// PT_NOTE The array element specifies the location and size of auxiliary information.
    NOTE = 4,
    /// PT_SHLIB This segment type is reserved but has unspecified semantics.
    SHLIB = 5,
    /// PT_PHDR The array element, if present, specifies the location and size of the program header
    /// table itself, both in the file and in the memory image of the program. This segment
    /// type may not occur more than once in a file. Moreover, it may occur only if the
    /// program header table is part of the memory image of the program. If it is present,
    /// it must precede any loadable segment entry.
    PHDR = 6,
    /// PT_LOPROC Values in this inclusive range are reserved for processor-specific semantics.
    LOPROC = 0x70000000,
    /// PT_HIPROC Values in this inclusive range are reserved for processor-specific semantics.
    HIPROC = 0x7fffffff,
    /// same as usual idk what you did
    _,
};

pub inline fn getShdr(Ehdr: *Elf32Ehdr) [*]Elf32Shdr {
    return @ptrFromInt(@intFromPtr(Ehdr) + Ehdr.shoff);
}

pub inline fn getSectionHeader(Ehdr: *Elf32Ehdr, index: usize) *Elf32Shdr {
    return &getShdr(Ehdr)[index];
}

pub inline fn getStrTable(Ehdr: *Elf32Ehdr) ?[*]u8 {
    if (Ehdr.shstrndx == ElfSpecialSections.UNDEF) {
        return null;
    }
}
