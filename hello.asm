org 0x0000
bits 16
mov ax,cs
mov ds,ax
mov si,msg
mov ah,0x0E
mov bx,7
.l:lodsb
or al,al
jz .d
int 0x10
jmp .l
.d:retf
msg db 'Hello from C0W program!',13,10,0
