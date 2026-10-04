; 桌面主循环、壁纸加载、任务栏、图标、点击分发

gui_main:
    call set_vga13
    call gui_load_wall
    jc .gm_nwall
    call gui_draw_desktop
    call mouse_init
    call gui_loop
    ret
.gm_nwall:
    call clr_vga
    call gui_draw_desktop
    call mouse_init
    call gui_loop
    ret

; gui_load_wall: 从 NXFS 读 WALL.BIN 或从 0x4D26 取内置壁纸
gui_load_wall:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push ds
%ifndef LIVE
    mov si,fn_wall
    mov ax,0x3000
    mov es,ax
    mov bx,0
    call nxfs_read_file
    jnc .gw_have
%endif
    mov ax,0x4D26
    mov es,ax
.gw_have:
    mov dx,0x3C8
    xor al,al
    out dx,al
    mov dx,0x3C9
    mov si,0
    mov cx,768
.gw_pal:
    mov al,[es:si]
    out dx,al
    inc si
    loop .gw_pal
    mov ax,es
    mov ds,ax
    mov ax,0xA000
    mov es,ax
    mov si,768
    xor di,di
    mov cx,32000
    rep movsw
    clc
    jmp .gw_done
.gw_done:
    pop ds
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; gui_draw_desktop: 画图标和任务栏
gui_draw_desktop:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    ; 图标
    mov cx,4
    mov dx,4
    mov al,0x09
    call draw_icon
    mov word [txt_x],8
    mov word [txt_y],28
    mov si,g_mycomp_l
    call draw_text
    mov cx,84
    mov dx,4
    mov al,0x0E
    call draw_icon
    mov word [txt_x],88
    mov word [txt_y],28
    mov si,g_cpanel_l
    call draw_text
    mov cx,164
    mov dx,4
    mov al,0x02
    call draw_icon
    mov word [txt_x],168
    mov word [txt_y],28
    mov si,g_book_l
    call draw_text
    mov cx,244
    mov dx,4
    mov al,0x04
    call draw_icon
    mov word [txt_x],248
    mov word [txt_y],28
    mov si,g_dos_l
    call draw_text
    ; 任务栏
    mov ax,0xA000
    mov es,ax
    mov di,184*320
    mov cx,16*320
    mov al,0x07
.tbl:
    mov [es:di],al
    inc di
    dec cx
    jnz .tbl
    ; 开始按钮
    mov di,184*320
    mov cx,16
.stb:
    push cx
    mov cx,48
    mov al,0x09
.stbx:
    mov [es:di],al
    inc di
    dec cx
    jnz .stbx
    sub di,48
    add di,320
    pop cx
    dec cx
    jnz .stb
    mov word [txt_x],6
    mov word [txt_y],184
    mov si,g_start
    call draw_text
    mov word [txt_x],250
    mov word [txt_y],184
    mov si,g_ver
    call draw_text
    ; 关机按钮
    mov di,184*320+292
    mov cx,16
.shb:
    push cx
    mov cx,28
    mov al,0x04
.shbx:
    mov [es:di],al
    inc di
    dec cx
    jnz .shbx
    sub di,28
    add di,320
    pop cx
    dec cx
    jnz .shb
    mov word [txt_x],294
    mov word [txt_y],184
    mov si,g_power
    call draw_text
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; gui_loop: 鼠标轮询 + 点击分发 + Esc/Ctrl+C 退出
gui_loop:
    call mouse_poll
    call draw_cursor
    mov al,[m_left]
    cmp al,[m_prev]
    je .gl2
    cmp al,1
    jne .gl2
    call gui_click
.gl2:
    mov al,[m_left]
    mov [m_prev],al
    call check_ctrlc
    jc gui_to_dos
    mov ah,1
    int 0x16
    jz .gl3
    mov ah,0
    int 0x16
    cmp al,27
    jne .gl3
    call gui_to_dos
.gl3:
    jmp gui_loop

gui_to_dos:
    mov ax,0x0003
    int 0x10
    jmp shell_loop

; gui_click: 按坐标分发
gui_click:
    push ax
    push bx
    mov ax,[m_x]
    mov bx,[m_y]
    cmp bx,52
    jae .c1
    cmp ax,80
    jae .c1
    call gui_mycomp
    jmp .cdone
.c1:
    cmp bx,52
    jae .c2
    cmp ax,160
    jae .c2
    cmp ax,80
    jb .c2
    call gui_cpanel
    jmp .cdone
.c2:
    cmp bx,52
    jae .c3
    cmp ax,240
    jae .c3
    cmp ax,160
    jb .c3
    call gui_book
    jmp .cdone
.c3:
    cmp bx,52
    jae .c4
    cmp ax,240
    jb .c4
    call gui_to_dos
    jmp .cdone
.c4:
    cmp bx,184
    jb .cdone
    cmp bx,200
    jae .cdone
    cmp ax,292
    jb .c5
    mov ax,0x0003
    int 0x10
    mov si,g_shutdown
    call print
    cli
    hlt
.c5:
    cmp ax,48
    jae .cdone
    call gui_start_menu
    jmp .cdone
.cdone:
    pop bx
    pop ax
    ret

; 桌面字符串
g_mycomp_l db '我的电脑',0
g_cpanel_l db '控制面板',0
g_book_l   db '桃花源记',0
g_dos_l    db 'NexDOS',0
g_start    db '开始',0
g_ver      db 'NexOS 1.0',0
g_power    db '关机',0
g_shutdown db '系统已关机, 可以安全关闭电源',13,10,0