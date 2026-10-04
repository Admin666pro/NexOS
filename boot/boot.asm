; NexOS - Stage1 Bootloader (512 bytes)
; 用 CHS 方式读取 stage2 到 0x0800
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

    mov [boot_drive], dl

    ; 复位磁盘
    mov ah, 0x00
    int 0x13

    ; 读取 stage2: 扇区1-16 (共16个扇区) 到 0x0000:0x0800
    ; 1.44MB软盘: 80柱面, 2磁头, 18扇区/道
    ; LBA 1 => CHS: 柱面0, 磁头0, 扇区2
    xor ax, ax
    mov es, ax
    mov bx, 0x0800       ; es:bx = 0x0000:0x0800

    mov ah, 0x02         ; 读扇区
    mov al, 16           ; 读16个扇区
    mov ch, 0            ; 柱面0
    mov cl, 2            ; 扇区2 (LBA1)
    mov dh, 0            ; 磁头0
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; 跳转到 stage2
    jmp 0x0000:0x0800

disk_error:
    mov ah, 0x0E
    mov al, 'E'
    int 0x10
    mov al, 'R'
    int 0x10
    mov al, 'R'
    int 0x10
.hang:
    hlt
    jmp .hang

boot_drive db 0x80

times 510 - ($ - $$) db 0
dw 0xAA55
