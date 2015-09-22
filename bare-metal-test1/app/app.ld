ENTRY(main)
SECTIONS
{
    . = 0x1064C;
    .startup . : { app_main.o(.text) }
    .text : { *(.text) }
    .data : { *(.data) }
}
