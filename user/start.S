.section .text
.global _start
.type _start, @function

_start:
    xor %ebp, %ebp
    call main
    mov $2, %eax
    int $0x80
1:  hlt
    jmp 1b