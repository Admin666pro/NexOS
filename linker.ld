ENTRY(_start)

SECTIONS {
    . = 0x10000;

    _kernel_start = .;

    .multiboot : {
        KEEP(*(.multiboot))
    }

    .text : {
        *(.text.entry)
        *(.text)
    }

    .rodata : { *(.rodata) }
    .data   : { *(.data) }

    .bss : {
        _bss_start = .;
        *(COMMON)
        *(.bss)
        _bss_end = .;
    }

    _kernel_end = .;
}