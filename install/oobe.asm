; 图形化安装向导 (OOBE), VGA 320x200

install_os:
    call set_vga13
    call mouse_init
    call oobe_welcome
    jc .io_exit
    call oobe_hd
    jc .io_exit
    call oobe_partsel
    jc .io_exit
    cmp al,1
    je .io_full
    cmp al,2
    je .io_fmt
    jmp .io_copy
.io_full:
    mov si,ow_stage_part
    call oobe_stage
    call do_partition
    jc .io_wrerr
.io_fmt:
    mov si,ow_stage_fmt
    call oobe_stage
    call do_format
    jc .io_wrerr
.io_copy:
    call oobe_copy
    jc .io_wrerr
    call oobe_done
.io_exit:
    call set_text
    ret
.io_wrerr:
    call oobe_errpage
    call set_text
    ret

; oobe_win: SI=标题, 全屏深蓝背景+顶部标题栏
oobe_win:
    push ax
    push bx
    push cx
    push dx
    mov [oobe_title_sv],si
    mov al,0x01
    mov cx,0
    mov dx,0
    mov bx,320
    mov si,200
    call fill_rect
    mov al,0x0B
    mov cx,0
    mov dx,0
    mov bx,320
    mov si,26
    call fill_rect
    mov word [txt_x],14
    mov word [txt_y],10
    mov si,[oobe_title_sv]
    mov byte [char_col],15
    call draw_text
    mov byte [char_col],7
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; oobe_btn: SI=文字, BL=1 高亮 (下一步按钮)
oobe_btn:
    push ax
    push bx
    push cx
    push dx
    mov [oobe_title_sv],si
    mov al,0x01
    mov cx,224
    mov dx,170
    mov bx,310
    mov si,190
    call fill_rect
    cmp bl,1
    jne .ob_off
    mov al,0x0B
    jmp .ob_fill
.ob_off:
    mov al,0x09
.ob_fill:
    mov cx,226
    mov dx,172
    mov bx,308
    mov si,188
    call fill_rect
    mov word [txt_x],244
    mov word [txt_y],177
    mov si,[oobe_title_sv]
    mov byte [char_col],15
    call draw_text
    mov byte [char_col],7
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; oobe_input: 等鼠标点击(视为 Enter)或键盘, 返回 AX
oobe_input:
.oi_loop:
    call mouse_poll
    call draw_cursor
    mov al,[m_left]
    cmp al,1
    jne .oi_kb
    cmp byte [m_prev],1
    je .oi_loop
    mov byte [m_prev],1
    mov ax,0x0D
    clc
    ret
.oi_kb:
    mov byte [m_prev],0
    mov ah,1
    int 0x16
    jz .oi_loop
    mov ah,0
    int 0x16
    ret

; oobe_waitkey: Enter->CF=0, Esc->CF=1
oobe_waitkey:
.owk:
    call oobe_input
    cmp al,0x1B
    je .owk_esc
    cmp al,0x0D
    je .owk_ok
    jmp .owk
.owk_esc:
    stc
    ret
.owk_ok:
    clc
    ret

; oobe_stage: 工作页, SI=阶段文字
oobe_stage:
    push si
    mov si,ow_work_title
    call oobe_win
    pop si
    mov word [txt_x],16
    mov word [txt_y],60
    call draw_text
    call oobe_waitkey
    ret

; oobe_welcome: 欢迎页
oobe_welcome:
    mov si,ow_win_title
    call oobe_win
    mov word [txt_x],16
    mov word [txt_y],44
    mov si,ow_welcome
    call draw_text
    mov word [txt_x],16
    mov word [txt_y],66
    mov si,ow_wtext1
    call draw_text
    mov word [txt_x],16
    mov word [txt_y],80
    mov si,ow_wtext2
    call draw_text
    mov word [txt_x],16
    mov word [txt_y],94
    mov si,ow_hint
    call draw_text
    mov bl,1
    mov si,btn_next
    call oobe_btn
    call oobe_waitkey
    ret

; oobe_hd: 硬盘检测页
oobe_hd:
.oh_l:
    mov si,ow_hd_title
    call oobe_win
    mov word [txt_x],16
    mov word [txt_y],48
    mov si,ow_detecting
    call draw_text
    call detect_hd
    jc .oh_nohd
    call show_hdinfo_oobe
    mov bl,1
    mov si,btn_next
    call oobe_btn
    call oobe_waitkey
    ret
.oh_nohd:
    mov word [txt_x],16
    mov word [txt_y],70
    mov si,ow_nohd1
    call draw_text
    mov word [txt_x],16
    mov word [txt_y],86
    mov si,ow_nohd2
    call draw_text
    mov bl,1
    mov si,btn_retry
    call oobe_btn
    call oobe_waitkey
    jnc .oh_l
    stc
    ret

; show_hdinfo_oobe: 硬盘参数, 窗口布局
show_hdinfo_oobe:
    push ax
    push bx
    push cx
    push dx
    mov dl,[hd_num]
    mov ah,0x08
    int 0x13
    movzx eax,ch
    movzx ebx,cl
    shr bl,6
    shl ebx,8
    add eax,ebx
    inc eax
    mov [hd_cyl],eax
    movzx ebx,dh
    inc ebx
    mov [hd_head],ebx
    movzx ebx,cl
    and ebx,0x3F
    mov [hd_spt],ebx
    mov eax,[hd_cyl]
    mov ebx,[hd_head]
    mul ebx
    mov ebx,[hd_spt]
    mul ebx
    mov [hd_sectors],eax
    mov ebx,2048
    div ebx
    mov [hd_mb],eax
    mov word [txt_x],16
    mov word [txt_y],68
    mov si,ow_hd_ok
    call draw_text
    movzx eax,byte [hd_num]
    call u32dec
    mov si,numbuf
    call draw_text
    mov word [txt_y],84
    mov si,ow_hd_cyl
    call draw_text
    mov eax,[hd_cyl]
    call u32dec
    mov si,numbuf
    call draw_text
    mov si,ow_comma
    call draw_text
    mov eax,[hd_head]
    call u32dec
    mov si,numbuf
    call draw_text
    mov si,ow_comma
    call draw_text
    mov eax,[hd_spt]
    call u32dec
    mov si,numbuf
    call draw_text
    mov word [txt_x],16
    mov word [txt_y],100
    mov si,ow_hd_mb
    call draw_text
    mov eax,[hd_mb]
    call u32dec
    mov si,numbuf
    call draw_text
    mov si,ow_mb
    call draw_text
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; oobe_partsel: 安装方式选择, AL=1/2/3, Esc->CF=1
oobe_partsel:
    mov si,ow_sel_title
    call oobe_win
    mov byte [sel_cur],1
.ps_l:
    mov word [txt_x],16
    mov word [txt_y],40
    mov si,ow_sel_ask
    call draw_text
    mov word [txt_y],120
    mov si,ow_sel_key
    call draw_text
    mov word [txt_y],62
    mov si,opt1
    mov cx,1
    call .ps_item
    mov word [txt_y],80
    mov si,opt2
    mov cx,2
    call .ps_item
    mov word [txt_y],98
    mov si,opt3
    mov cx,3
    call .ps_item
.ps_in:
    call mouse_poll
    call draw_cursor
    mov al,[m_left]
    cmp al,1
    jne .ps_kb
    cmp byte [m_prev],1
    je .ps_kb
    mov byte [m_prev],1
    mov ax,[m_x]
    mov bx,[m_y]
    cmp bx,62
    jb .ps_in_ok
    cmp bx,78
    jb .ps_c1
    cmp bx,80
    jb .ps_in_ok
    cmp bx,96
    jb .ps_c2
    cmp bx,98
    jb .ps_in_ok
    cmp bx,114
    jb .ps_c3
    jmp .ps_in_ok
.ps_c1:
    mov byte [sel_cur],1
    jmp .ps_ok
.ps_c2:
    mov byte [sel_cur],2
    jmp .ps_ok
.ps_c3:
    mov byte [sel_cur],3
    jmp .ps_ok
.ps_in_ok:
    mov ax,0x0D00
    jmp .ps_got
.ps_kb:
    mov byte [m_prev],0
    mov ah,1
    int 0x16
    jz .ps_in
    mov ah,0
    int 0x16
.ps_got:
    cmp al,0x1B
    je .ps_esc
    cmp al,0x0D
    je .ps_ok
    cmp ah,0x48
    jne .ps_k1
    dec byte [sel_cur]
    cmp byte [sel_cur],0
    jg .ps_l
    mov byte [sel_cur],1
    jmp .ps_l
.ps_k1:
    cmp ah,0x50
    jne .ps_l
    inc byte [sel_cur]
    cmp byte [sel_cur],4
    jl .ps_l
    mov byte [sel_cur],3
    jmp .ps_l
.ps_ok:
    mov al,[sel_cur]
    clc
    ret
.ps_esc:
    stc
    ret

; .ps_item: 画选项行, CX=选项号, SI=文本
.ps_item:
    push ax
    push bx
    push cx
    push dx
    push si
    mov ax,[txt_y]
    sub ax,2
    mov dx,ax
    add ax,16
    mov si,ax
    mov al,0x01
    mov cx,12
    mov bx,312
    call fill_rect
    pop si
    cmp cl,[sel_cur]
    jne .ps_it
    mov word [txt_x],16
    push si
    mov si,ow_sel_mark
    call draw_text
    pop si
    mov word [txt_x],28
    call draw_text
    jmp .ps_ix
.ps_it:
    mov word [txt_x],16
    call draw_text
.ps_ix:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; oobe_prog: AX=百分比, 进度条
oobe_prog:
    push ax
    push bx
    push cx
    push dx
    mov [ow_pct_cur],ax
    mov al,0x0F
    mov cx,18
    mov dx,86
    mov bx,302
    mov si,102
    call fill_rect
    mov al,0x00
    mov cx,20
    mov dx,88
    mov bx,300
    mov si,100
    call fill_rect
    mov ax,[ow_pct_cur]
    mov cx,ax
    mov ax,280
    mul cx
    mov bx,100
    div bx
    mov dx,ax
    add dx,20
    mov al,0x02
    mov cx,20
    mov bx,dx
    mov dx,88
    mov si,100
    call fill_rect
    mov al,0x01
    mov cx,24
    mov dx,70
    mov bx,200
    mov si,86
    call fill_rect
    mov word [txt_x],24
    mov word [txt_y],70
    mov si,ow_done_pct
    call draw_text
    movzx eax,word [ow_pct_cur]
    call u32dec
    mov si,numbuf
    call draw_text
    mov si,ow_pct
    call draw_text
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; oobe_copy: 复制文件页
oobe_copy:
    mov si,ow_copy_title
    call oobe_win
    mov word [txt_x],16
    mov word [txt_y],40
    mov si,ow_copy_text
    call draw_text
    mov word [txt_x],16
    mov word [txt_y],114
    mov si,ow_copy_warn
    call draw_text
    call do_copy
    jc .oc_e
    mov ax,100
    call oobe_prog
    clc
    ret
.oc_e:
    stc
    ret

; oobe_done: 完成页
oobe_done:
    mov si,ow_done_title
    call oobe_win
    mov word [txt_x],16
    mov word [txt_y],60
    mov si,ow_done1
    call draw_text
    mov word [txt_x],16
    mov word [txt_y],80
    mov si,ow_done2
    call draw_text
    mov word [txt_x],16
    mov word [txt_y],94
    mov si,ow_done3
    call draw_text
    mov word [txt_x],16
    mov word [txt_y],110
    mov si,ow_rebooting
    call draw_text
    mov cx,0x3000
.dly1:
    push cx
    mov cx,0x3000
.dly2:
    dec cx
    jnz .dly2
    pop cx
    dec cx
    jnz .dly1
    int 0x19
    ret

; oobe_errpage: 写盘失败页
oobe_errpage:
    mov si,ow_err_title
    call oobe_win
    mov word [txt_x],16
    mov word [txt_y],60
    mov si,ow_err1
    call draw_text
    mov word [txt_x],16
    mov word [txt_y],78
    mov si,ow_err2
    call draw_text
    mov bl,1
    mov si,btn_retry
    call oobe_btn
    call oobe_waitkey
    ret

; OOBE 字符串
ow_win_title  db 'NexOS 安装程序',0
ow_welcome    db '欢迎使用 NexOS 安装程序',0
ow_wtext1     db '本程序将把 NexOS 安装到您的硬盘。',0
ow_wtext2     db '安装将格式化硬盘，请备份数据！',0
ow_hint       db '按 Enter 继续，按 Esc 退出。',0
btn_next      db '下一步 >',0
btn_retry     db '重试',0
btn_reboot    db '重启',0
ow_hd_title   db '硬盘检测',0
ow_detecting  db '正在检测硬盘，请稍候...',0
ow_hd_ok      db '检测到硬盘：',0
ow_hd_cyl     db '参数：',0
ow_comma      db ',',0
ow_hd_mb      db '容量：',0
ow_mb         db ' MB',0
ow_nohd1      db '未检测到硬盘！',0
ow_nohd2      db '请检查硬盘连接后重试。',0
ow_sel_title  db '选择安装方式',0
ow_sel_ask    db '请选择安装方式：',0
opt1          db '1) 分区并格式化为 NXFS',0
opt2          db '2) 仅格式化（不分区）',0
opt3          db '3) 跳过（保留现有数据）',0
ow_sel_key    db '按上下方向键选择，按 Enter 确认',0
ow_sel_mark   db '>',0
ow_work_title db '正在安装',0
ow_stage_part db '正在分区...',0
ow_stage_fmt  db '正在格式化...',0
ow_copy_title db '正在复制文件',0
ow_copy_text  db '正在复制文件到硬盘：',0
ow_copy_warn  db '请勿关闭电源或重启电脑...',0
ow_file_hello db '正在复制 HELLO...',0
ow_file_readme db '正在复制 README...',0
ow_file_taohua db '正在复制 TAOHUA...',0
ow_file_wall  db '正在复制 WALL.BIN...',0
ow_done_pct   db '已完成 ',0
ow_pct        db '%',0
ow_done_title db '安装完成',0
ow_done1      db 'NexOS 安装完成！',0
ow_done2      db '正在重新启动...',0
ow_done3      db '正在重新启动...',0
ow_rebooting  db '正在重新启动...',0
ow_err_title  db '安装失败',0
ow_err1       db '写入硬盘失败！',0
ow_err2       db '请检查硬盘后重新安装。',0

sel_cur     db 1
ow_pct_cur  dw 0