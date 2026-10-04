; 桃花源记阅读器: 原文/翻译切换, 分页

gui_book:
    mov si,g_book_title
    mov [g_ptitle],si
    mov byte [g_bmode],0
    mov byte [g_bpage],0
    call book_load
    jnc .book_ok
    call clr_vga
    mov word [txt_x],40
    mov word [txt_y],90
    mov si,g_book_err
    call draw_text
    mov word [txt_x],40
    mov word [txt_y],120
    mov si,g_anykey
    call draw_text
.wb_err:
    call win_loop
    cmp al,0xFF
    jne .wb_err
    call clr_vga
    call gui_draw_desktop
    ret
.book_ok:
.book_loop:
    call clr_vga
    call gui_page_head
    call book_set_content
    call copy_page_to_buf
    mov word [txt_x],4
    mov word [txt_y],24
    mov si,page_buf
    call draw_text
    ; 底部按钮
    mov al,0x07
    mov cx,4
    mov dx,184
    mov bx,60
    mov si,199
    call fill_rect
    mov byte [char_col],0
    mov word [txt_x],8
    mov word [txt_y],186
    mov si,g_btn_prev
    call draw_text
    mov al,0x07
    mov cx,100
    mov dx,184
    mov bx,156
    mov si,199
    call fill_rect
    mov word [txt_x],104
    mov word [txt_y],186
    mov si,g_btn_tr
    call draw_text
    mov al,0x07
    mov cx,200
    mov dx,184
    mov bx,256
    mov si,199
    call fill_rect
    mov word [txt_x],204
    mov word [txt_y],186
    mov si,g_btn_next
    call draw_text
    mov al,0x07
    mov cx,276
    mov dx,184
    mov bx,316
    mov si,199
    call fill_rect
    mov word [txt_x],280
    mov word [txt_y],186
    mov si,g_w_close
    call draw_text
    mov byte [char_col],7
.wb:
    call mouse_poll
    call draw_cursor
    mov al,[m_left]
    cmp al,[m_prev]
    je .wb_kb
    cmp al,1
    jne .wb_kb
    mov ax,[m_x]
    mov bx,[m_y]
    cmp bx,16
    jb .wb_btn
    cmp bx,184
    jae .wb_btns
    jmp .wb_kb2
.wb_btn:
    cmp ax,260
    jae .book_done
    jmp .wb_kb2
.wb_btns:
    cmp ax,60
    jb .book_prev
    cmp ax,100
    jb .wb_kb2
    cmp ax,156
    jb .book_toggle
    cmp ax,200
    jb .wb_kb2
    cmp ax,256
    jb .book_next
    cmp ax,276
    jb .wb_kb2
    cmp ax,316
    jbe .book_done
.wb_kb2:
    mov al,[m_left]
    mov [m_prev],al
    jmp .wb_kb
.wb_kb:
    mov al,[m_left]
    mov [m_prev],al
    mov ah,1
    int 0x16
    jz .wb
    mov ah,0
    int 0x16
    cmp al,27
    je .book_done
    cmp al,'t'
    je .book_toggle
    cmp al,'T'
    je .book_toggle
    cmp al,' '
    je .book_next
    cmp al,13
    je .book_next
    cmp al,'p'
    je .book_next
    cmp al,'P'
    je .book_next
    cmp al,'b'
    je .book_prev
    cmp al,'B'
    je .book_prev
    cmp al,0
    jne .wb
    cmp ah,0x4D
    je .book_next
    cmp ah,0x4B
    je .book_prev
    jmp .wb
.book_next:
    inc byte [g_bpage]
    call book_bounds
    jmp .book_loop
.book_prev:
    dec byte [g_bpage]
    call book_bounds
    jmp .book_loop
.book_toggle:
    xor byte [g_bmode],1
    mov byte [g_bpage],0
    jmp .book_loop
.book_done:
    call clr_vga
    call gui_draw_desktop
    ret

; book_load: 从 NXFS 读 TAOHUA.TXT 到 0x2000:0, 失败从 0x4C26 复制
book_load:
    push ax
    push si
    push bx
    push es
%ifndef LIVE
    mov si,fn_taohua
    mov ax,0x2000
    mov es,ax
    xor bx,bx
    call nxfs_read_file
    jnc .bt_ok
%endif
    push ds
    push di
    mov ax,0x4C26
    mov ds,ax
    mov ax,0x2000
    mov es,ax
    xor si,si
    xor di,di
    mov cx,2048
    rep movsw
    pop di
    pop ds
.bt_ok:
    pop es
    pop bx
    pop si
    pop ax
    ret

; book_set_content: 计算当前页起始偏移 (段 0x2000)
book_set_content:
    push ax
    push cx
    push si
    push di
    push es
    mov ax,0x2000
    mov es,ax
    xor si,si
    cmp byte [g_bmode],0
    je .bsc_find
.bsc_scan:
    mov al,[es:si]
    inc si
    cmp al,0x0C
    jne .bsc_scan
.bsc_find:
    mov cl,[g_bpage]
    xor ch,ch
.bsc_skip:
    cmp cx,0
    je .bsc_done
    mov al,[es:si]
    cmp al,0
    je .bsc_done
    cmp al,0x0C
    je .bsc_done
    cmp al,10
    jne .bsc_next
    dec cx
.bsc_next:
    inc si
    jmp .bsc_skip
.bsc_done:
    mov [g_content],si
    pop es
    pop di
    pop si
    pop cx
    pop ax
    ret

; copy_page_to_buf: 复制当前页 8 行到 page_buf
copy_page_to_buf:
    push ax
    push cx
    push si
    push di
    push es
    mov ax,0x2000
    mov es,ax
    mov si,[g_content]
    mov di,page_buf
    mov cx,8
.cpb_line:
    push cx
.cpb_ch:
    mov al,[es:si]
    cmp al,0
    je .cpb_eol
    cmp al,0x0C
    je .cpb_eol
    cmp al,13
    je .cpb_cr
    mov [di],al
    inc si
    inc di
    jmp .cpb_ch
.cpb_cr:
    mov byte [di],13
    inc di
    mov byte [di],10
    inc di
    inc si
    mov al,[es:si]
    cmp al,10
    jne .cpb_noskip
    inc si
.cpb_noskip:
    pop cx
    dec cx
    jz .cpb_done
    jmp .cpb_line
.cpb_eol:
    mov byte [di],0
    inc di
.cpb_scan:
    mov al,[es:si]
    cmp al,0
    je .cpb_eof
    cmp al,0x0C
    je .cpb_eof
    cmp al,10
    je .cpb_adv
    inc si
    jmp .cpb_scan
.cpb_adv:
    inc si
    pop cx
    dec cx
    jz .cpb_done
    jmp .cpb_line
.cpb_eof:
    pop cx
.cpb_done:
    pop es
    pop di
    pop si
    pop cx
    pop ax
    ret

; book_bounds: 页号环绕 (原文 0..4, 翻译 0..5)
book_bounds:
    push ax
    cmp byte [g_bmode],0
    jne .bb_tr
    cmp byte [g_bpage],0xFF
    jne .bb_ok
    mov byte [g_bpage],4
    jmp .bb_done
.bb_ok:
    cmp byte [g_bpage],5
    jb .bb_done
    mov byte [g_bpage],0
    jmp .bb_done
.bb_tr:
    cmp byte [g_bpage],0xFF
    jne .bb_ok2
    mov byte [g_bpage],5
    jmp .bb_done
.bb_ok2:
    cmp byte [g_bpage],6
    jb .bb_done
    mov byte [g_bpage],0
.bb_done:
    pop ax
    ret

; 字符串/数据
g_book_title db '桃花源记',0
g_book_err   db '未找到 TAOHUA.TXT',13,10,'请先安装 NexOS 到硬盘!',0
g_btn_prev   db '上一页',0
g_btn_tr     db '翻译',0
g_btn_next   db '下一页',0
g_bmode      db 0
g_bpage      db 0
page_buf     times 400 db 0