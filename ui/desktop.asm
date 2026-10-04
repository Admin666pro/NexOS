; NexOS - 桌面环境与窗口管理器

extern fill_rect
extern draw_string
extern clear_screen
extern serial_print
extern screen_width
extern screen_height
extern mouse_x
extern mouse_y
extern mouse_buttons
extern framebuffer_addr
extern screen_pitch

section .data
; 颜色定义
COLOR_BG        equ 0x1a1a2e      ; 桌面背景深蓝
COLOR_TITLEBAR  equ 0x16213e      ; 标题栏
COLOR_WINDOW    equ 0x0f3460      ; 窗口背景
COLOR_TEXT      equ 0xFFFFFF       ; 白色文字
COLOR_ACCENT    equ 0xe94560       ; 强调色红
COLOR_TASKBAR   equ 0x0f0f23       ; 任务栏
taskbar_dbg     db "[NexOS] taskbar", 13, 10, 0
COLOR_MENU_BG   equ 0x2d2d44       ; 菜单背景

; 窗口结构 (简化): 每个窗口 32 字节
; 0: x, 4: y, 8: w, 12: h, 16: title_ptr, 20: flags, 24: z_order, 28: content_callback
MAX_WINDOWS equ 8
window_count dd 0
windows times MAX_WINDOWS * 32 db 0

; 拖拽状态
drag_active db 0
drag_window dd -1
drag_offset_x dd 0
drag_offset_y dd 0

section .text

; 绘制桌面背景
global desktop_draw_background
desktop_draw_background:
    push COLOR_BG
    call clear_screen
    add esp, 4

    ; 绘制桌面图标文字
    push COLOR_TEXT
    push .welcome_str
    push 30
    push 30
    call draw_string
    add esp, 16

    push COLOR_ACCENT
    push .ver_str
    push 30
    push 55
    call draw_string
    add esp, 16

    ret

.welcome_str db "NexOS Desktop", 0
.ver_str db "v0.1 - Assembly Edition", 0

; 绘制任务栏
global desktop_draw_taskbar
desktop_draw_taskbar:
    mov eax, [screen_height]
    sub eax, 40

    ; 任务栏背景
    push COLOR_TASKBAR
    push 40
    push dword [screen_width]
    push eax
    push 0
    call fill_rect
    add esp, 20

    ; 开始按钮
    push COLOR_ACCENT
    push 36
    push 100
    push eax
    push 4
    call fill_rect
    add esp, 20

    push COLOR_TEXT
    push .start_str
    add eax, 10
    push eax
    push 20
    call draw_string
    add esp, 16

    ; 时钟区域文字
    mov eax, [screen_width]
    sub eax, 120
    push COLOR_TEXT
    push .time_str
    mov ebx, [screen_height]
    sub ebx, 30
    push ebx
    push eax
    call draw_string
    add esp, 16

    ret

.start_str db "[ Start ]", 0
.time_str db "00:00:00", 0

; 创建一个窗口
; 参数: x, y, w, h, title_ptr
; 返回: 窗口索引 (eax)
global window_create
window_create:
    push ebp
    mov ebp, esp

    mov eax, [window_count]
    cmp eax, MAX_WINDOWS
    jge .fail

    ; 计算窗口结构地址
    mov ecx, 32
    mul ecx
    lea edi, [windows + eax]

    ; 填充窗口数据
    mov eax, [ebp+8]
    mov [edi], eax          ; x
    mov eax, [ebp+12]
    mov [edi+4], eax        ; y
    mov eax, [ebp+16]
    mov [edi+8], eax        ; w
    mov eax, [ebp+20]
    mov [edi+12], eax       ; h
    mov eax, [ebp+24]
    mov [edi+16], eax       ; title_ptr
    mov dword [edi+20], 1   ; flags = visible
    mov eax, [window_count]
    mov [edi+24], eax       ; z_order

    inc dword [window_count]
    mov eax, [window_count]
    dec eax
    jmp .done
.fail:
    mov eax, -1
.done:
    pop ebp
    ret

; 绘制所有窗口
global windows_draw_all
windows_draw_all:
    push ebx
    push esi

    mov ebx, 0              ; 窗口索引
.loop:
    cmp ebx, [window_count]
    jge .done

    mov eax, ebx
    mov ecx, 32
    mul ecx
    lea esi, [windows + eax]

    ; 检查是否可见
    cmp dword [esi+20], 0
    je .next

    ; 绘制窗口
    push esi
    call window_draw_one
    add esp, 4

.next:
    inc ebx
    jmp .loop
.done:
    pop esi
    pop ebx
    ret

; 绘制单个窗口
; 参数: 窗口结构指针
window_draw_one:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov esi, [ebp+8]

    ; 窗口主体
    push COLOR_WINDOW
    push dword [esi+12]    ; h
    push dword [esi+8]     ; w
    push dword [esi+4]     ; y
    push dword [esi]       ; x
    call fill_rect
    add esp, 20

    ; 标题栏 (高度 28)
    push COLOR_TITLEBAR
    push 28
    push dword [esi+8]     ; w
    push dword [esi+4]     ; y
    push dword [esi]       ; x
    call fill_rect
    add esp, 20

    ; 标题文字
    push COLOR_TEXT
    push dword [esi+16]     ; title
    mov ebx, [esi+4]
    add ebx, 6
    push ebx
    mov eax, [esi]
    add eax, 8
    push eax
    call draw_string
    add esp, 16

    ; 关闭按钮 (红色方块)
    mov eax, [esi]        ; x
    add eax, [esi+8]      ; x + w (重新读取，ecx已被fill_rect破坏)
    sub eax, 24
    mov ebx, [esi+4]      ; y
    add ebx, 4
    push COLOR_ACCENT
    push 20
    push 20
    push ebx
    push eax
    call fill_rect
    add esp, 20

    ; 窗口边框
    ; 上边框
    mov eax, [esi]
    mov ebx, [esi+4]
    push 0xFFFFFF
    push dword [esi+8]
    push 1
    push ebx
    push eax
    call fill_rect
    add esp, 20
    ; 下边框
    mov eax, [esi]
    mov ebx, [esi+4]
    add ebx, [esi+12]
    dec ebx
    push 0xFFFFFF
    push dword [esi+8]
    push 1
    push ebx
    push eax
    call fill_rect
    add esp, 20
    ; 左边框
    mov eax, [esi]
    mov ebx, [esi+4]
    push 0xFFFFFF
    push 1
    push dword [esi+12]
    push ebx
    push eax
    call fill_rect
    add esp, 20
    ; 右边框
    mov eax, [esi]
    add eax, [esi+8]
    dec eax
    mov ebx, [esi+4]
    push 0xFFFFFF
    push 1
    push dword [esi+12]
    push ebx
    push eax
    call fill_rect
    add esp, 20

    pop edi
    pop esi
    pop ebx
    pop ebp
    ret

; 处理鼠标点击 - 窗口拖拽
; 参数: 鼠标按键状态
global window_handle_click
window_handle_click:
    push ebp
    mov ebp, esp

    mov al, [mouse_buttons]
    test al, 1              ; 左键
    jz .check_release

    ; 左键按下 - 检查是否点在标题栏上
    cmp byte [drag_active], 1
    je .done

    mov ebx, 0
.check_loop:
    cmp ebx, [window_count]
    jge .done

    mov eax, ebx
    mov ecx, 32
    mul ecx
    lea esi, [windows + eax]

    ; 检查鼠标是否在窗口范围内
    mov eax, [mouse_x]
    cmp eax, [esi]
    jl .next_win
    mov ecx, [esi]
    add ecx, [esi+8]
    cmp eax, ecx
    jge .next_win

    mov eax, [mouse_y]
    cmp eax, [esi+4]
    jl .next_win
    mov ecx, [esi+4]
    add ecx, 28             ; 标题栏高度
    cmp eax, ecx
    jge .next_win

    ; 点在标题栏上 - 开始拖拽
    mov byte [drag_active], 1
    mov [drag_window], ebx
    mov eax, [mouse_x]
    sub eax, [esi]
    mov [drag_offset_x], eax
    mov eax, [mouse_y]
    sub eax, [esi+4]
    mov [drag_offset_y], eax
    jmp .done

.next_win:
    inc ebx
    jmp .check_loop

.check_release:
    ; 左键松开 - 停止拖拽
    mov byte [drag_active], 0
    mov dword [drag_window], -1

.done:
    pop ebp
    ret

; 更新拖拽中的窗口位置
global window_update_drag
window_update_drag:
    cmp byte [drag_active], 1
    jne .done

    mov ebx, [drag_window]
    cmp ebx, 0
    jl .done
    cmp ebx, [window_count]
    jge .done

    mov eax, ebx
    mov ecx, 32
    mul ecx
    lea esi, [windows + eax]

    mov eax, [mouse_x]
    sub eax, [drag_offset_x]
    mov [esi], eax
    mov eax, [mouse_y]
    sub eax, [drag_offset_y]
    mov [esi+4], eax

.done:
    ret
