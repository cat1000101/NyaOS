ENTRY(_start)

SECTIONS
{
    . = 0x400000;                 /* relocate to address 0 */

    .text ALIGN(16):
    {
        *(.text)           /* include all other .text sections */
    }

    .data ALIGN(16):
    {
        *(.data)
    }

    .rodata ALIGN(16):
    {
        *(.rodata*)
    }
}