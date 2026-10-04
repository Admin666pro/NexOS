org 0x0000
bits 16

start:
    cli
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    mov [boot_drv], dl

    mov al, 'H'         ; H = hdboot 开始
    call putc

    ; 读 kernel (LBA 2 开始, 32 个扇区 = 16KB) 到 0x0840:0
    mov word [lba], 2
    mov word [cnt], 32
    xor bx, bx

read_loop:
    mov ax, 0x0840
    mov es, ax
    mov word [dap_seg], 0x0840
    mov word [dap_off], bx
    mov ax, [lba]
    mov word [dap_lba], ax
    mov word [dap_lba+2], 0
    mov dl, [boot_drv]
    mov ah, 0x42
    mov si, dap
    int 0x13
    jc boot_err

    mov al, '.'         ; . = 一个扇区读成功
    call putc

    add bx, 512
    inc word [lba]
    dec word [cnt]
    jnz read_loop

    mov al, 'K'         ; K = 内核全部读完
    call putc

    ; 从 MZ 头读入口点
    mov dl, [boot_drv]  ; 先保存启动驱动器号
    mov ax, 0x0840
    mov ds, ax
    mov ax, [0x16]      ; MZ 头中的 CS
    mov bx, [0x14]      ; MZ 头中的 IP
    add ax, 0x0840      ; 实际 CS = 加载段 + CS

    mov al, 'J'         ; J = 即将跳转
    push ax
    push bx
    call putc

    pop bx
    pop ax
    push ax
    push bx
    retf                ; 跳到 CS:IP

putc:
    push ax
    push bx
    mov ah, 0x0E
    mov bx, 7
    int 0x10
    pop bx
    pop ax
    ret

boot_err:
    mov al, 'E'         ; E = 读盘失败
    call putc
    hlt
    jmp $

boot_drv db 0
lba      dw 0
cnt      dw 0

dap      db 0x10,0
dap_cnt  dw 1
dap_off  dw 0
dap_seg  dw 0x0840
dap_lba  dd 0
         dd 0

times 512-($-$$) db 0