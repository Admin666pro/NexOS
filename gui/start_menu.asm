; 开始菜单: 4 项, 点击执行, 点击外部/Esc 关闭

gui_start_menu:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    ; 菜单背景 (2,140)-(154,196)
    mov ax,0xA000
    mov es,ax
    mov di,140*320+2
    mov cx,15
.gm_row:
    push cx
    mov cx,152
    mov al,0x07
.gm_px:
    mov [es:di],al
    inc di
    dec cx
    jnz .gm_px
    add di,320-152
    pop cx
    dec cx
    jnz .gm_row
    ; 4 项
    mov byte [char_col],0
    mov word [txt_x],8
    mov word [txt_y],142
    mov si,g_dos_l
    call draw_text
    mov word [txt_x],8
    mov word [txt_y],156
    mov si,g_power
    call draw_text
    mov word [txt_x],8
    mov word [txt_y],170
    mov si,g_about_title
    call draw_text
    mov word [txt_x],8
    mov word [txt_y],184
    mov si,g_reinst_title
    call draw_text
    mov byte [char_col],7
.gm_l:
    call mouse_poll
    call draw_cursor
    mov al,[m_left]
    cmp al,[m_prev]
    je .gm_kb
    cmp al,1
    jne .gm_kb
    mov ax,[m_x]
    mov bx,[m_y]
    cmp bx,140
    jb .gm_close
    cmp bx,196
    jae .gm_close
    cmp ax,2
    jb .gm_close
    cmp ax,154
    jae .gm_close
    cmp bx,154
    jb .gm_nexdos
    cmp bx,168
    jb .gm_power
    cmp bx,182
    jb .gm_about
    call sub_reinst
    call gui_sub
    jmp .gm_close
.gm_nexdos:
    call gui_to_dos
    jmp .gm_close
.gm_power:
    mov ax,0x0003
    int 0x10
    mov si,g_shutdown
    call print
    cli
    hlt
.gm_about:
    call sub_about
    call gui_sub
    jmp .gm_close
.gm_kb:
    mov al,[m_left]
    mov [m_prev],al
    mov ah,1
    int 0x16
    jz .gm_l
    mov ah,0
    int 0x16
    cmp al,27
    je .gm_close
    jmp .gm_l
.gm_close:
    call clr_vga
    call gui_draw_desktop
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret