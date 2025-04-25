pub const regs16 = extern struct {
    di: u16 = 0,
    si: u16 = 0,
    bp: u16 = 0,
    sp: u16 = 0,
    bx: u16 = 0,
    dx: u16 = 0,
    cx: u16 = 0,
    ax: u16 = 0,
    gs: u16 = 0,
    fs: u16 = 0,
    es: u16 = 0,
    ds: u16 = 0,
    eflags: u16 = 0,
};

extern fn int32(u8, *regs16) void;

pub fn int32Wrapper(int_num: u8, regs: *regs16) void {
    int32(int_num, regs);
}
