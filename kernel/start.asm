; 内核入口: 设置段寄存器、栈，安装键盘中断，调用 kmain
start:
    cli
    mov ax,0x0840
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov sp,0xFFF0
    sti
    mov [boot_drv],dl
    call kb_setup
    call kmain
    jmp $