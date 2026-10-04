; NexOS - 内核主函数
extern vga_init
extern clear_screen
extern fill_rect
extern draw_string
extern keyboard_init
extern keyboard_handler
extern keyboard_getchar_nb
extern mouse_init
extern mouse_handler
extern mouse_draw_cursor
extern mouse_x
extern mouse_y
extern mouse_buttons
extern screen_width
extern screen_height
extern screen_pitch
extern screen_bpp
extern framebuffer_addr
extern desktop_draw_background
extern desktop_draw_taskbar
extern window_create
extern windows_draw_all
extern window_handle_click
extern window_update_drag
extern idt_set_gate
extern idt_load
extern irq0_stub
extern irq1_stub
extern irq12_stub

section .data
win1_title db "Welcome to NexOS", 0
win2_title db "System Info", 0
win3_title db "Terminal", 0
msg_start   db "[NexOS] kernel_main", 13, 10, 0
msg_fb      db "[NexOS] fb=", 0
msg_pre_clear  db "[NexOS] before clear", 13, 10, 0
msg_post_clear db "[NexOS] after clear", 13, 10, 0
msg_idt     db "[NexOS] idt+kbd done", 13, 10, 0
msg_loop    db "[NexOS] main loop", 13, 10, 0
msg_newline db 13, 10, 0
msg_space   db " ", 0

section .text
global kernel_main
global serial_print
global serial_print_hex
kernel_main:
    call serial_init
    push msg_start
    call serial_print
    add esp, 4

    call vga_init

    push 0x1a1a2e
    call clear_screen
    add esp, 4

    call idt_init_pic
    call keyboard_init
    call mouse_init
    call timer_init
    sti

    call desktop_draw_background

    push win1_title
    push 150
    push 400
    push 300
    push 100
    call window_create
    add esp, 20

    push win2_title
    push 200
    push 350
    push 100
    push 450
    call window_create
    add esp, 20

    push win3_title
    push 150
    push 300
    push 350
    push 150
    call window_create
    add esp, 20

    push msg_loop
    call serial_print
    add esp, 4

.main_loop:
    ; 确保 VGA 帧缓冲映射稳定 (PCI BAR0 = 0xE0000000)
    mov dx, 0xCF8
    mov eax, 0x80000000 | (0 << 16) | (2 << 11) | (0 << 8) | 0x10
    out dx, eax
    mov dx, 0xCFC
    mov eax, 0xE0000000
    out dx, eax

    call desktop_draw_background
    call windows_draw_all
    call desktop_draw_taskbar
    call window_handle_click
    call window_update_drag
    call mouse_draw_cursor
    call keyboard_getchar_nb
    test al, al
    jz .no_key
.no_key:
    mov ecx, 300000
.delay:
    dec ecx
    jnz .delay
    jmp .main_loop

.hang:
    cli
    hlt
    jmp .hang

; ===== 串口调试 =====
serial_init:
    mov al, 0x80
    out 0x3FB, al
    mov al, 0x03
    out 0x3F8, al
    mov al, 0x00
    out 0x3F9, al
    mov al, 0x03
    out 0x3FB, al
    mov al, 0x00
    out 0x3F9, al
    ret

serial_putchar:
    push eax
    push edx
    push ecx
    mov cl, al
.wait:
    mov dx, 0x3FD
    in al, dx
    test al, 0x20
    jz .wait
    mov al, cl
    mov dx, 0x3F8
    out dx, al
    pop ecx
    pop edx
    pop eax
    ret

serial_print:
    push ebp
    mov ebp, esp
    push esi
    mov esi, [ebp+8]
.loop:
    mov al, [esi]
    test al, al
    jz .done
    call serial_putchar
    inc esi
    jmp .loop
.done:
    pop esi
    pop ebp
    ret

serial_print_hex:
    push ebx
    push ecx
    mov ecx, 8
.loop:
    rol eax, 4
    mov bl, al
    and bl, 0x0F
    cmp bl, 10
    jl .digit
    add bl, 'A' - 10
    jmp .put
.digit:
    add bl, '0'
.put:
    push eax
    mov al, bl
    call serial_putchar
    pop eax
    dec ecx
    jnz .loop
    pop ecx
    pop ebx
    ret

; ===== PIC + IDT =====
global idt_init_pic
idt_init_pic:
    mov al, 0x11
    out 0x20, al
    out 0xA0, al
    mov al, 0x20
    out 0x21, al
    mov al, 0x28
    out 0xA1, al
    mov al, 0x04
    out 0x21, al
    mov al, 0x02
    out 0xA1, al
    mov al, 0x01
    out 0x21, al
    out 0xA1, al
    mov al, 0xF9
    out 0x21, al
    mov al, 0xEF
    out 0xA1, al

    push 0x8E
    push 0x08
    push irq0_stub
    push 0x20
    call idt_set_gate
    add esp, 16

    push 0x8E
    push 0x08
    push irq1_stub
    push 0x21
    call idt_set_gate
    add esp, 16

    push 0x8E
    push 0x08
    push irq12_stub
    push 0x2C
    call idt_set_gate
    add esp, 16

    call idt_load
    ret

; ===== 定时器 =====
global timer_init
timer_init:
    mov al, 0x36
    out 0x43, al
    mov ax, 11931
    out 0x40, al
    mov al, ah
    out 0x40, al
    ret

global timer_handler
timer_handler:
    ret
