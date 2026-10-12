SECTIONS
{
    .text.boot : { *(.text.boot) }
    .text : { *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    . = ALIGN(8);
    bss_begin = .;
    .bss (NOLOAD) : { *(.bss*) *(COMMON) }
    . = ALIGN(8);
    bss_end = .;

    ASSERT((bss_begin & 7) == 0, "BSS start must be 8-byte aligned")
    ASSERT((bss_end & 7) == 0, "BSS end must be 8-byte aligned")
}
