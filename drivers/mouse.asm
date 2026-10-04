; PS/2 鼠标驱动

m_x         dw 160
m_y         dw 100
m_left      db 0
m_prev      db 0
mp_st       db 0
mp_b0       db 0
mp_xd       db 0
mp_yd       db 0
cur_visible db 0
old_x       dw 0
old_y       dw 0

; "↖" 光标 16x16 XOR 字形
cur_shape:
    db 0xF0,0x00, 0xE8,0x00, 0xC8,0x00, 0x88,0x00
    db 0x84,0x00, 0x82,0x00, 0x81,0x00, 0x80,0x80
    db 0x80,0x40, 0x80,0x20, 0x80,0x10, 0x80,0x08
    db 0x80,0x04, 0x80,0x02, 0x80,0x01, 0x80,0x01

mouse_init:
    push ax
    push cx
    call kb_wait
    mov al,0xA8
    out 0x64,al
    call kb_wait
    mov al,0xD4
    out 0x64,al
    call kb_wait
    mov al,0xF6
    out 0x60,al
    call mouse_ack
    call kb_wait
    mov al,0xD4
    out 0x64,al
    call kb_wait
    mov al,0xF4
    out 0x60,al
    call mouse_ack
    mov byte [mp_st],0
    mov byte [m_left],0
    mov byte [m_prev],0
    pop cx
    pop ax
    ret

kb_wait:
    push ax
    push cx
    mov cx,0xFFFF
.kw:
    in al,0x64
    test al,2
    jz .kw_done
    dec cx
    jnz .kw
.kw_done:
    pop cx
    pop ax
    ret

mouse_ack:
    push ax
    push cx
    mov cx,0xFFFF
.ma:
    in al,0x64
    test al,1
    jnz .ma_got
    dec cx
    jnz .ma
    jmp .ma_done
.ma_got:
    in al,0x60
.ma_done:
    pop cx
    pop ax
    ret

; mouse_poll: 读 3 字节包, 更新 m_x/m_y/m_left
mouse_poll:
    push ax
.mp:
    in al,0x64
    test al,0x20
    jz .mpd
    in al,0x60
    cmp byte [mp_st],0
    jne .mp1
    test al,0x08
    jz .mp
    mov [mp_b0],al
    mov byte [mp_st],1
    jmp .mpd
.mp1:
    cmp byte [mp_st],1
    jne .mp2
    mov [mp_xd],al
    mov byte [mp_st],2
    jmp .mpd
.mp2:
    mov [mp_yd],al
    mov byte [mp_st],0
    mov al,[mp_b0]
    and al,1
    mov [m_left],al
    mov al,[mp_xd]
    cbw
    mov bx,ax
    mov ax,[m_x]
    add ax,bx
    cmp ax,0
    jge .mx1
    mov ax,0
.mx1:
    cmp ax,319
    jle .mx2
    mov ax,319
.mx2:
    mov [m_x],ax
    mov al,[mp_yd]
    cbw
    mov bx,ax
    mov ax,[m_y]
    sub ax,bx
    cmp ax,0
    jge .my1
    mov ax,0
.my1:
    cmp ax,199
    jle .my2
    mov ax,199
.my2:
    mov [m_y],ax
.mpd:
    pop ax
    ret

; draw_cursor: 擦旧画新, XOR 绘制
draw_cursor:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    cmp byte [cur_visible],0
    je .draw_new
    mov cx,[old_x]
    mov dx,[old_y]
    cmp cx,[m_x]
    jne .do_erase
    cmp dx,[m_y]
    je .no_change
.do_erase:
    call .core
.draw_new:
    mov cx,[m_x]
    mov dx,[m_y]
    mov [old_x],cx
    mov [old_y],dx
    call .core
    mov byte [cur_visible],1
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
.no_change:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
.core:
    push ds
    mov ax,0xA000
    mov es,ax
    mov bx,cur_shape
    mov di,0
.cy:
    call check_ctrlc
    jc .cx_exit
    mov bp,cx
    mov ax,dx
    push dx
    mov si,320
    mul si
    pop dx
    add bp,ax
    mov al,[bx+di]
    mov ah,0x80
.cbit_l:
    test al,ah
    jz .cb_l0
    xor byte [es:bp],0x0F
.cb_l0:
    inc bp
    shr ah,1
    cmp ah,0
    jne .cbit_l
    mov al,[bx+di+1]
    mov ah,0x80
.cbit_r:
    test al,ah
    jz .cb_r0
    xor byte [es:bp],0x0F
.cb_r0:
    inc bp
    shr ah,1
    cmp ah,0
    jne .cbit_r
    add di,2
    inc dx
    cmp di,32
    jne .cy
    pop ds
    ret
.cx_exit:
    pop ds
    ret