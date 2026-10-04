.section .text
.global isr128
isr128:
    cli
    push $0
    push $128
    jmp isr_common