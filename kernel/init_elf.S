.section .rodata
.global init_elf_start
.global init_elf_end

.align 4
init_elf_start:
    .incbin "build/init.elf"
init_elf_end: