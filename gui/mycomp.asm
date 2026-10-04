; 我的电脑、控制面板、子页

; 我的电脑: 显示硬盘信息
gui_mycomp:
    mov si,g_pc_title
    mov [g_ptitle],si
    mov si,g_pc_info
    mov [g_content],si
    call gui_page
    ret

; 控制面板: 4 项菜单
gui_cpanel:
    mov si,g_cp_title
    mov [g_ptitle],si
    mov si,g_cp_menu
    mov [g_content],si
.gcm_redraw:
    call clr_vga
    call gui_page_head
    mov word [txt_x],4
    mov word [txt_y],24
    mov si,g_cp_menu
    call draw_text
.gcm:
    call mouse_poll
    call draw_cursor
    mov al,[m_left]
    cmp al,[m_prev]
    je .gcm_kb
    cmp al,1
    jne .gcm_kb
    mov ax,[m_x]
    mov bx,[m_y]
    cmp bx,16
    jb .gcm_btn
    cmp bx,40
    jb .gcm_1
    cmp bx,56
    jb .gcm_2
    cmp bx,72
    jb .gcm_3
    cmp bx,88
    jb .gcm_4
    jmp .gcm_kb2
.gcm_btn:
    cmp ax,260
    jae .gcm_done
    jmp .gcm_kb2
.gcm_1:
    call sub_show
    call gui_sub
    jmp .gcm_redraw
.gcm_2:
    call sub_snd
    call gui_sub
    jmp .gcm_redraw
.gcm_3:
    call sub_about
    call gui_sub
    jmp .gcm_redraw
.gcm_4:
    call sub_reinst
    call gui_sub
    jmp .gcm_redraw
.gcm_kb:
    mov al,[m_left]
    mov [m_prev],al
    mov ah,1
    int 0x16
    jz .gcm
    mov ah,0
    int 0x16
    cmp al,27
    je .gcm_done
    cmp al,'1'
    je .gcm_1
    cmp al,'2'
    je .gcm_2
    cmp al,'3'
    je .gcm_3
    cmp al,'4'
    je .gcm_4
    jmp .gcm
.gcm_kb2:
    mov al,[m_left]
    mov [m_prev],al
    jmp .gcm
.gcm_done:
    call clr_vga
    call gui_draw_desktop
    ret

; 子页选择
sub_show:
    mov si,g_cp_show
    mov [g_content],si
    mov si,g_show_title
    mov [g_ptitle],si
    ret
sub_snd:
    mov si,g_cp_snd
    mov [g_content],si
    mov si,g_snd_title
    mov [g_ptitle],si
    ret
sub_about:
    mov si,g_cp_about
    mov [g_content],si
    mov si,g_about_title
    mov [g_ptitle],si
    ret
sub_reinst:
    mov si,g_cp_reinst
    mov [g_content],si
    mov si,g_reinst_title
    mov [g_ptitle],si
    ret

; 字符串
g_pc_title   db '我的电脑',0
g_cp_title   db '控制面板',0
g_show_title db '显示设置',0
g_snd_title  db '声音设置',0
g_about_title db '关于NexOS',0
g_reinst_title db '重装系统',0

g_pc_info db '硬盘: NXFS 已安装',13,10,13,10
          db '根目录:',13,10
          db 'HELLO.C0W',13,10
          db 'README.TXT',13,10,13,10
          db '容量: 63MB (IDE)',0
g_cp_menu db '1. 显示',13,10
          db '2. 声音',13,10
          db '3. 关于NexOS',13,10
          db '4. 重装系统',0
g_cp_show db '分辨率: 320x200',13,10
          db '颜色: 256色',13,10
          db '4:3 模式',13,10
          db '(8K 需要显卡支持)',0
g_cp_snd  db '音量: 100',13,10
          db '静音: 关',13,10
          db '声道: 立体声',13,10
          db '输出: 扬声器',0
g_cp_about db 'NexOS v1.0',13,10
           db '使用豆包开发',13,10
           db '(c) 2026 作者微信 hksxlyb',13,10
           db '捐赠: C:/NexOS/skm.jpg',0
g_cp_reinst db '重装 NexOS:',13,10
            db '进入 NexDOS 后',13,10
            db '输入 INSTALL 回车',0