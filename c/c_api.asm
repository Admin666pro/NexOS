; C 调用汇编的 wrapper, 约定 __watcall
; 参数: AX=第1个, BX=第2个, CX=第3个, DX=第4个
bits 16

global c_puts
global c_putc
global c_newline
global c_cls

; void c_puts(const char *s)
c_puts:
    mov si,ax
    call print
    ret

; void c_putc(char c)
c_putc:
    mov ah,0x0E
    mov bx,7
    int 0x10
    ret

; void c_newline(void)
c_newline:
    call newline
    ret

; void c_cls(void)
c_cls:
    mov ax,0x0003
    int 0x10
    ret