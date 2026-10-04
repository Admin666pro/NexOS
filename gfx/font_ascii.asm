; 8x16 ASCII 字库渲染
; AH=字符, CX=x, DX=y (像素坐标)
; 字库段 0x0B40, 每字符 16 字节

draw_char_asc:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov al,ah
    xor ah,ah
    shl ax,4
    mov si,ax
    mov bx,0x0B40
    mov es,bx
    mov bx,cx
    mov di,16
.ac_r:
    push di
    push si
    mov al,es:[si]
    mov si,8
.ac_c:
    push ax
    push si
    mov ah,al
    test ah,0x80
    jz .ac_nxt
    mov ax,bx
    mov cx,8
    sub cx,si
    add ax,cx
    mov cx,ax
    mov al,[char_col]
    call put_pixel
.ac_nxt:
    pop si
    pop ax
    shl al,1
    dec si
    jnz .ac_c
    pop si
    inc si
    pop di
    inc dx
    dec di
    jnz .ac_r
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret