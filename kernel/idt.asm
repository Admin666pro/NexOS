; NexOS - IDT + 中断处理存根
section .data
idt_start:
    times 256 dq 0
idt_end:
idt_ptr:
    dw idt_end - idt_start - 1
    dd idt_start

section .text
global idt_set_gate
idt_set_gate:
    push ebp
    mov ebp, esp
    mov eax, [ebp+8]
    mov ecx, [ebp+12]
    mov [idt_start + eax*8], cx
    mov word [idt_start + eax*8 + 2], 0x08
    mov byte [idt_start + eax*8 + 4], 0
    mov byte [idt_start + eax*8 + 5], 0x8E
    shr ecx, 16
    mov [idt_start + eax*8 + 6], cx
    pop ebp
    ret

global idt_load
idt_load:
    lidt [idt_ptr]
    ret

global irq1_stub
irq1_stub:
    pushad
    cld
    extern keyboard_handler
    call keyboard_handler
    mov al, 0x20
    out 0x20, al
    popad
    iret

global irq12_stub
irq12_stub:
    pushad
    cld
    extern mouse_handler
    call mouse_handler
    mov al, 0x20
    out 0xA0, al
    out 0x20, al
    popad
    iret

global irq0_stub
irq0_stub:
    pushad
    cld
    extern timer_handler
    call timer_handler
    mov al, 0x20
    out 0x20, al
    popad
    iret
