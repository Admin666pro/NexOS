/* Multiboot 头 —— 给 GRUB 用 */
.section .multiboot, "a"
.align 4
.long 0x1BADB002
.long 0x0
.long -(0x1BADB002)

/* 内核入口 —— 两种方式都从这里开始 */
.section .text.entry
.global _start
.type _start, @function

_start:
    cli
    mov $stack_top, %esp
    mov %esp, %ebp

    /* 清 BSS */
    mov $_bss_start, %edi
    mov $_bss_end, %ecx
    sub %edi, %ecx
    xor %eax, %eax
    rep stosb

    call kmain

1:  cli
    hlt
    jmp 1b

.section .bss
.align 16
stack_bottom:
    .skip 16384
stack_top: