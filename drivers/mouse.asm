; NexOS - PS/2 鼠标驱动

extern screen_width
extern screen_height
extern fill_rect

section .data
global mouse_x
global mouse_y
global mouse_buttons
global mouse_event
mouse_x         dd 400
mouse_y         dd 300
mouse_buttons   db 0
mouse_event     db 0
mouse_cycle     db 0
mouse_packet    times 4 db 0

section .text
global mouse_init
mouse_init:
    mov al, 0xA8
    out 0x64, al
    mov al, 0x20
    out 0x64, al
    call mouse_wait_read
    in al, 0x60
    or al, 0x02
    mov bl, al
    mov al, 0x60
    out 0x64, al
    call mouse_wait_write
    mov al, bl
    out 0x60, al
    ; 发送鼠标命令 0xF6 (Set Defaults)
    mov al, 0xD4
    out 0x64, al
    call mouse_wait_write
    mov al, 0xF6
    out 0x60, al
    call mouse_wait_read
    in al, 0x60         ; ACK

    ; 发送鼠标命令 0xF4 (Enable Data Reporting)
    mov al, 0xD4
    out 0x64, al
    call mouse_wait_write
    mov al, 0xF4
    out 0x60, al
    call mouse_wait_read
    in al, 0x60         ; ACK
    ret

mouse_wait_write:
    in al, 0x64
    test al, 0x02
    jnz mouse_wait_write
    ret

mouse_wait_read:
    in al, 0x64
    test al, 0x01
    jz mouse_wait_read
    ret

global mouse_handler
mouse_handler:
    movzx eax, byte [mouse_cycle]
    in al, 0x60
    mov ecx, [mouse_cycle]
    mov [mouse_packet + ecx], al
    inc byte [mouse_cycle]
    cmp byte [mouse_cycle], 3
    jl .done
    mov byte [mouse_cycle], 0
    mov al, [mouse_packet]
    mov [mouse_buttons], al
    movsx eax, byte [mouse_packet + 1]
    add [mouse_x], eax
    movsx eax, byte [mouse_packet + 2]
    neg eax
    add [mouse_y], eax
    mov eax, [mouse_x]
    cmp eax, 0
    jge .x_ok
    mov dword [mouse_x], 0
.x_ok:
    mov eax, [screen_width]
    cmp [mouse_x], eax
    jl .x_ok2
    mov [mouse_x], eax
    dec dword [mouse_x]
.x_ok2:
    mov eax, [mouse_y]
    cmp eax, 0
    jge .y_ok
    mov dword [mouse_y], 0
.y_ok:
    mov eax, [screen_height]
    cmp [mouse_y], eax
    jl .y_ok2
    mov [mouse_y], eax
    dec dword [mouse_y]
.y_ok2:
    mov byte [mouse_event], 1
.done:
    ret

global mouse_draw_cursor
mouse_draw_cursor:
    push ebp
    mov ebp, esp
    mov eax, [mouse_x]
    mov ebx, [mouse_y]
    ; 外框黑色
    push 0x000000
    push 14
    push 14
    push ebx
    push eax
    call fill_rect
    add esp, 20
    ; 内部白色
    inc eax
    inc ebx
    push 0xFFFFFF
    push 12
    push 12
    push ebx
    push eax
    call fill_rect
    add esp, 20
    ; 中心点红色
    add eax, 4
    add ebx, 4
    push 0xFF0000
    push 4
    push 4
    push ebx
    push eax
    call fill_rect
    add esp, 20
    pop ebp
    ret
