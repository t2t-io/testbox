ENTRY(_Reset)
MEMORY
{
    RAM (rwx): ORIGIN = 0x10000, LENGTH = 120K
}

SECTIONS
{
    .startup :
    {
        system_startup.o(.text);
    } >RAM

    .text :
    {
        *(.text);
        _sidata = .;
    } >RAM

    .data :
    {
        _x_data_start = .;
        *(.data);
        _x_data_end = .;
    } >RAM

    .bss :
    {
        _x_bss_start = .;
        *(.bss COMMON);         /* zero-initialized memory */
        _x_bss_end = .;
    }

    stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
