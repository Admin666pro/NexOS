; 16x16 中文字库渲染 (GB2312)
; AL=高字节, AH=低字节, CX=x, DX=y
; 字库每行 2 字节, 共 16 行 32 字节
; 段: 0x0B40 + 每 256 个汉字跳 0x1000 段

draw_char_han:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    mov bx,cx
    mov bp,dx
    push ax
    mov cl,al
    xor ch,ch
    sub cl,0xA1
    mov ax,cx
    mov cx,94
    mul cx
    mov cx,ax
    pop ax
    mov dl,ah
    xor dh,dh
    sub dl,0xA1
    add cx,dx
    mov ax,cx
    shl ax,5
    add ax,0x1000
    mov si,ax
    pushf
    mov ax,cx
    shr ax,11
    popf
    adc ax,0
    shl ax,12
    add ax,0x0B40
    mov es,ax
    mov di,16
.hn_r:
    push di
    push si
    mov ax,es:[si]
    xchg al,ah
    mov si,16
.hn_c:
    push ax
    push si
    test ah,0x80
    jz .hn_nxt
    mov cx,16
    sub cx,si
    mov ax,bx
    add ax,cx
    mov cx,ax
    mov ax,bp
    mov dx,16
    sub dx,di
    add ax,dx
    mov dx,ax
    mov al,[char_col]
    call put_pixel
.hn_nxt:
    pop si
    pop ax
    shl ax,1
    dec si
    jnz .hn_c
    pop si
    add si,2
    pop di
    dec di
    jnz .hn_r
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret