; VGA 图形基础

; set_vga13: 切到 320x200 256 色
set_vga13:
    push ax
    mov ax,0x0013
    int 0x10
    pop ax
    ret

; set_text: 切回 80x25 文本模式
set_text:
    push ax
    mov ax,0x0003
    int 0x10
    pop ax
    ret

; clr_vga: 用 0 清屏
clr_vga:
    push ax
    push cx
    push di
    push es
    mov ax,0xA000
    mov es,ax
    xor di,di
    mov cx,32000
    xor ax,ax
    rep stosw
    pop es
    pop di
    pop cx
    pop ax
    ret

; put_pixel: CX=x, DX=y, AL=颜色
put_pixel:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    push ax
    mov ax,dx
    mov bx,320
    mul bx
    add ax,cx
    mov di,ax
    pop ax
    mov bx,0xA000
    mov es,bx
    mov [es:di],al
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; fill_rect: AL=颜色, CX=x1, DX=y1, BX=x2, SI=y2
fill_rect:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov di,bx
    mov bx,dx
.fr_y:
    mov dx,bx
    push cx
.fr_x:
    push ax
    push dx
    call put_pixel
    pop dx
    pop ax
    inc cx
    cmp cx,di
    jbe .fr_x
    pop cx
    inc bx
    cmp bx,si
    jbe .fr_y
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; draw_icon: 16x16 色块, CX=x, DX=y, AL=填充色
draw_icon:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    mov bx,0xA000
    mov es,bx
    mov ax,dx
    mov bx,320
    mul bx
    add ax,cx
    mov di,ax
    mov cx,16
.irow:
    push cx
    mov cx,16
.irowx:
    mov [es:di],al
    inc di
    dec cx
    jnz .irowx
    add di,304
    pop cx
    dec cx
    jnz .irow
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret