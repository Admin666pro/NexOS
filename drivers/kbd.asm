; 键盘驱动：int 0x09 硬件中断 + int 0x16 服务

kb_buf   times 128 db 0
kb_head  dw 0
kb_tail  dw 0
kb_ctrl  db 0
kb_shift db 0
kb_ctrlc db 0

; 扫描码 -> ASCII (make code 1, 0x00-0x57)
scancode_map:
    db 0,0x1B,'1','2','3','4','5','6','7','8','9','0','-','=',0x08,0x09
    db 'q','w','e','r','t','y','u','i','o','p','[',']',0x0D,0,'a','s'
    db 'd','f','g','h','j','k','l',';',0x27,'`',0,0x5C,'z','x','c','v'
    db 'b','n','m',',','.','/',0,'*',0,' ',0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0

; int 0x09: 键盘硬件中断
kbd_isr:
    push ax
    push bx
    push si
    push ds
    mov ax,0x0840
    mov ds,ax
    in al,0x60
    mov bl,al
    in al,0x61
    mov ah,al
    or al,0x80
    out 0x61,al
    xchg ah,al
    out 0x61,al
    mov al,0x20
    out 0x20,al
    test bl,0x80
    jnz .kb_rel
    mov al,bl
    cmp al,0x1D
    je .kb_ctrl_on
    cmp al,0x2A
    je .kb_shift_on
    cmp al,0x36
    je .kb_shift_on
    cmp al,0x2E
    jne .kb_chk
    cmp byte [kb_ctrl],1
    jne .kb_chk
    mov byte [kb_ctrlc],1
    jmp .kb_exit
.kb_chk:
    cmp al,0x3B
    jb .kb_map
    cmp al,0x44
    jbe .kb_ext
    cmp al,0x47
    jb .kb_map
    cmp al,0x53
    jbe .kb_ext
.kb_map:
    cmp al,0x57
    ja .kb_exit
    mov bx,scancode_map
    xor ah,ah
    add bx,ax
    mov al,[bx]
    or al,al
    jz .kb_exit
    cmp byte [kb_shift],1
    jne .kb_shift_ok
    cmp al,'a'
    jb .kb_shift_ok
    cmp al,'z'
    ja .kb_shift_ok
    sub al,0x20
.kb_shift_ok:
    xor ah,ah
    jmp .kb_push
.kb_ext:
    mov ah,al
    xor al,al
.kb_push:
    mov si,[kb_head]
    mov [kb_buf+si],ax
    add si,2
    and si,0x7E
    mov [kb_head],si
    jmp .kb_exit
.kb_ctrl_on:
    mov byte [kb_ctrl],1
    jmp .kb_exit
.kb_shift_on:
    mov byte [kb_shift],1
    jmp .kb_exit
.kb_rel:
    and al,0x7F
    cmp al,0x1D
    je .kb_ctrl_off
    cmp al,0x2A
    je .kb_shift_off
    cmp al,0x36
    je .kb_shift_off
.kb_exit:
    pop ds
    pop si
    pop bx
    pop ax
    iret
.kb_ctrl_off:
    mov byte [kb_ctrl],0
    jmp .kb_exit
.kb_shift_off:
    mov byte [kb_shift],0
    jmp .kb_exit

; int 0x16: 键盘服务
; AH=0 读键(阻塞), AH=1 检测(ZF=1 无键), AH=2 shift 状态
int16_isr:
    pushf
    cli
    push bx
    push si
    push ds
    push bp
    mov bp,sp
    mov ax,0x0840
    mov ds,ax
    cmp ah,0
    je .i16_read
    cmp ah,1
    je .i16_check
    cmp ah,2
    je .i16_shift
.i16_ret:
    pop bp
    pop ds
    pop si
    pop bx
    popf
    iret
.i16_shift:
    mov al,0
    cmp byte [kb_ctrl],1
    jne .i16_s2
    or al,0x04
.i16_s2:
    cmp byte [kb_shift],1
    jne .i16_s3
    or al,0x08
.i16_s3:
    jmp .i16_ret
.i16_read:
    mov si,[kb_tail]
    cmp si,[kb_head]
    jne .i16_got
    sti
    hlt
    cli
    jmp .i16_read
.i16_got:
    mov ax,[kb_buf+si]
    add si,2
    and si,0x7E
    mov [kb_tail],si
    jmp .i16_ret
.i16_check:
    mov si,[kb_tail]
    cmp si,[kb_head]
    jne .i16_ck1
    or word [bp+14],0x40
    jmp .i16_ret
.i16_ck1:
    and word [bp+14],0xFFBF
    jmp .i16_ret

; kb_setup: 安装 int 0x09 / int 0x16 中断向量
kb_setup:
    push ax
    push bx
    push es
    cli
    mov ax,0
    mov es,ax
    mov di,0x09*4
    mov word [es:di],kbd_isr
    mov word [es:di+2],0x0840
    mov di,0x16*4
    mov word [es:di],int16_isr
    mov word [es:di+2],0x0840
    mov word [kb_head],0
    mov word [kb_tail],0
    mov byte [kb_ctrl],0
    mov byte [kb_shift],0
    mov byte [kb_ctrlc],0
    sti
    pop es
    pop bx
    pop ax
    ret

; check_ctrlc: 有 Ctrl+C 则清标志并 CF=1
check_ctrlc:
    push ax
    push ds
    mov ax,0x0840
    mov ds,ax
    cli
    mov al,[kb_ctrlc]
    mov byte [kb_ctrlc],0
    sti
    or al,al
    jnz .cc_y
    pop ds
    pop ax
    clc
    ret
.cc_y:
    pop ds
    pop ax
    stc
    ret

; wait_key: 等任意键
wait_key:
    mov ah,0
    int 0x16
    ret

; wait_yn: 等 Y/N, 返回 AL='Y' 或 'N'
wait_yn:
.wy:
    mov ah,0
    int 0x16
    and al,0xDF
    cmp al,'Y'
    je .wy_y
    cmp al,'N'
    je .wy_n
    jmp .wy
.wy_y:
    mov al,'Y'
    ret
.wy_n:
    mov al,'N'
    ret