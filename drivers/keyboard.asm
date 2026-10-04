; NexOS - PS/2 键盘驱动
section .data
global key_buffer
global key_buffer_head
global key_buffer_tail
global shift_state
global caps_lock
key_buffer      times 256 db 0
key_buffer_head dd 0
key_buffer_tail dd 0
shift_state     db 0
caps_lock       db 0

scancode_low:
    db 0, 27, '1','2','3','4','5','6','7','8','9','0','-','=', 8, 9
    db 'q','w','e','r','t','y','u','i','o','p','[',']', 13, 0, 'a','s'
    db 'd','f','g','h','j','k','l',';',"'",'`', 0,'\','z','x','c','v'
    db 'b','n','m',',','.','/', 0, '*', 0, ' ', 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, '7','8','9','-','4','5','6','+','1'
    db '2','3','0','.', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    times 128 db 0

scancode_high:
    db 0, 27, '!','@','#','$','%','^','&','*','(',')','_','+', 8, 9
    db 'Q','W','E','R','T','Y','U','I','O','P','{','}', 13, 0, 'A','S'
    db 'D','F','G','H','J','K','L',':','"','~', 0,'|','Z','X','C','V'
    db 'B','N','M','<','>','?', 0, '*', 0, ' ', 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, '7','8','9','-','4','5','6','+','1'
    db '2','3','0','.', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    times 128 db 0

section .text
global keyboard_init
keyboard_init:
    in al, 0x64
    test al, 1
    jz .no_data
    in al, 0x60
.no_data:
    ret

global keyboard_handler
keyboard_handler:
    in al, 0x60
    mov ah, al
    cmp al, 0x2A
    je .shift_down
    cmp al, 0x36
    je .shift_down
    cmp al, 0xAA
    je .shift_up
    cmp al, 0xB6
    je .shift_up
    cmp al, 0x3A
    je .caps_toggle
    test al, 0x80
    jnz .done
    movzx ebx, al
    mov cl, [shift_state]
    test cl, cl
    jz .use_low
    mov al, [scancode_high + ebx]
    jmp .check_caps
.use_low:
    mov al, [scancode_low + ebx]
.check_caps:
    mov cl, [caps_lock]
    test cl, cl
    jz .put_char
    cmp al, 'a'
    jb .put_char
    cmp al, 'z'
    ja .put_char
    sub al, 32
.put_char:
    mov edx, [key_buffer_head]
    mov [key_buffer + edx], al
    inc edx
    and edx, 0xFF
    mov [key_buffer_head], edx
    jmp .done
.shift_down:
    mov byte [shift_state], 1
    jmp .done
.shift_up:
    mov byte [shift_state], 0
    jmp .done
.caps_toggle:
    test ah, 0x80
    jnz .done
    not byte [caps_lock]
.done:
    ret

global keyboard_getchar_nb
keyboard_getchar_nb:
    mov eax, [key_buffer_head]
    mov ebx, [key_buffer_tail]
    cmp eax, ebx
    je .empty
    mov al, [key_buffer + ebx]
    inc ebx
    and ebx, 0xFF
    mov [key_buffer_tail], ebx
    ret
.empty:
    mov al, 0
    ret
