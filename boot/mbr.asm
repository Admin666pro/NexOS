org 0x7C00
bits 16

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    mov [boot_drv], dl

    mov al, 'M'         ; M = MBR 开始
    call putc

    ; 读 hdboot (LBA 1) 到 0x0600:0
    mov word [dap_seg], 0x0600
    mov word [dap_off], 0
    mov word [dap_lba], 1
    mov word [dap_lba+2], 0
    mov dl, [boot_drv]
    mov ah, 0x42
    mov si, dap
    int 0x13
    jc boot_err

    mov al, 'R'         ; R = MBR 读盘成功
    call putc

    mov dl, [boot_drv]
    jmp 0x0600:0x0000

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
    mov al, 'E'         ; E = MBR 读盘失败
    call putc
    hlt
    jmp $

boot_drv db 0

dap      db 0x10,0
dap_cnt  dw 1
dap_off  dw 0
dap_seg  dw 0x0600
dap_lba  dd 1
         dd 0

times 510-($-$$) db 0
dw 0xAA55