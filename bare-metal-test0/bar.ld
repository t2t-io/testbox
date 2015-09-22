ENTRY(bar_main)
SECTIONS
{
 . = 0x1064C;
 .startup . : { bar.o(.text) }
 .text : { *(.text) }
 .data : { *(.data) }
}
