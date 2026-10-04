.section .text
.global switch_to
.type switch_to, @function

switch_to:
    mov 4(%esp), %eax        # &old->esp
    mov 8(%esp), %edx        # new->esp

    push %ebp
    push %ebx
    push %esi
    push %edi

    mov %esp, (%eax)         # 保存旧栈
    mov %edx, %esp           # 加载新栈

    pop %edi
    pop %esi
    pop %ebx
    pop %ebp
    ret