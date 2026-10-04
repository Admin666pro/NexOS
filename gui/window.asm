; 窗口基础: 标题栏、内容区、按钮、事件循环

; gui_page: 通用页, 用 g_ptitle/g_content
gui_page:
    push ax
    call clr_vga
    call gui_page_head
.wp:
    call win_loop
    call clr_vga
    call gui_draw_desktop
    pop ax
    ret

; gui_page_head: 画标题栏 + 内容
gui_page_head:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov ax,0xA000
    mov es,ax
    mov di,0
    mov cx,16
.ph:
    push cx
    mov cx,320
    mov al,0x09
.phx:
    mov [es:di],al
    inc di
    dec cx
    jnz .phx
    pop cx
    dec cx
    jnz .ph
    ; 三按钮
    mov di,260
    mov cx,16
.bt_min:
    push cx
    mov cx,16
    mov al,0x07
.bt_minx:
    mov [es:di],al
    inc di
    dec cx
    jnz .bt_minx
    sub di,16
    add di,320
    pop cx
    dec cx
    jnz .bt_min
    mov di,278
    mov cx,16
.bt_max:
    push cx
    mov cx,16
    mov al,0x07
.bt_maxx:
    mov [es:di],al
    inc di
    dec cx
    jnz .bt_maxx
    sub di,16
    add di,320
    pop cx
    dec cx
    jnz .bt_max
    mov di,296
    mov cx,16
.bt_cls:
    push cx
    mov cx,16
    mov al,0x04
.bt_clsx:
    mov [es:di],al
    inc di
    dec cx
    jnz .bt_clsx
    sub di,16
    add di,320
    pop cx
    dec cx
    jnz .bt_cls
    mov word [txt_x],298
    mov word [txt_y],0
    mov si,g_w_close
    call draw_text
    mov word [txt_x],280
    mov word [txt_y],0
    mov si,g_w_max
    call draw_text
    mov word [txt_x],262
    mov word [txt_y],0
    mov si,g_w_min
    call draw_text
    mov word [txt_x],4
    mov word [txt_y],2
    mov si,[g_ptitle]
    call draw_text
    mov word [txt_x],4
    mov word [txt_y],24
    mov si,[g_content]
    test si,si
    jz .ph_skip
    call draw_text
.ph_skip:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; win_loop: 返回 al=按键, al=0xFF 表示关闭
win_loop:
    call mouse_poll
    call draw_cursor
    mov al,[m_left]
    cmp al,[m_prev]
    je .wl2
    cmp al,1
    jne .wl2
    call win_click
    cmp ax,1
    jne .wl2
    mov byte [m_prev],1
    mov al,0xFF
    ret
.wl2:
    mov al,[m_left]
    mov [m_prev],al
    mov ah,1
    int 0x16
    jz .wl3
    mov ah,0
    int 0x16
    cmp al,27
    jne .wl_key
    mov al,0xFF
    ret
.wl_key:
    ret
.wl3:
    jmp win_loop

; win_click: 标题栏右侧 (x>=260, y<16) 视为关闭
win_click:
    mov ax,[m_x]
    mov bx,[m_y]
    cmp bx,16
    jae .wc0
    cmp ax,260
    jae .wc_close
    mov ax,0
    ret
.wc_close:
    mov ax,1
    ret
.wc0:
    mov ax,0
    ret

; gui_sub: 子页, 等键返回 (si=[g_content])
gui_sub:
    push ax
    call clr_vga
    call gui_page_head
    mov word [txt_x],4
    mov word [txt_y],24
    mov si,[g_content]
    call draw_text
    mov word [txt_x],4
    mov word [txt_y],184
    mov si,g_anykey
    call draw_text
.ws:
    call win_loop
    pop ax
    ret

; 窗口字符串
g_anykey db '按任意键返回桌面',0
g_w_close db 'x',0
g_w_max   db '[]',0
g_w_min   db '-',0

g_ptitle  dw 0
g_content dw 0