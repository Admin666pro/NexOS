.section .text
.global enter_usermode
.type enter_usermode, @function

/* void enter_usermode(uint32_t entry, uint32_t user_stack) */
enter_usermode:
    mov 4(%esp), %eax
    mov 8(%esp), %edx

    cli

    push $0x23
    push %edx
    push $0x202
    push $0x1B
    push %eax

    mov $0x23, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs

    iret
