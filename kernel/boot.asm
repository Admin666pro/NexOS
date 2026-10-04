; NexOS Kernel Entry (纯汇编引导，无 multiboot)
section .text
global _start
_start:
    mov esp, 0x90000
    extern kernel_main
    call kernel_main
    cli
.hang:
    hlt
    jmp .hang
