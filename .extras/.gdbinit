target remote localhost:1234
file ./zig-out/extra/kernel.elf
add-symbol-file ./zig-out/extra/doomgeneric.elf

set logging file ./.extras/gdb.log
set logging enabled on

lay src

b kmain

define logbt
  set logging enabled off
  set logging redirect on
  set logging enabled on
  bt
  set logging enabled off
  set logging redirect off
  set logging enabled on
  end