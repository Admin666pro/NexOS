global c_puts_
global c_putc_
global c_newline_
global c_cls_

c_puts_:
    mov si,ax
    call print
    ret

c_putc_:
    mov ah,0x0E
    mov bx,7
    int 0x10
    ret

c_newline_:
    call newline
    ret

c_cls_:
    mov ax,0x0003
    int 0x10
    ret