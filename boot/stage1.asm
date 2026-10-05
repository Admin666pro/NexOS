; stage1: 512 字节 MBR
org 0x7C00
bits 16

STAGE2_LBA      equ 1
STAGE2_SECTORS  equ 16
STAGE2_LOAD     equ 0x7E00          ; 物理地址
STAGE2_MAGIC    equ 0x324E5853      ; "SXN2" 小端

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [boot_drv], dl

    ; 读 stage2 到 0x0000:0x7E00
    mov word [dap_count], STAGE2_SECTORS
    mov word [dap_offset], STAGE2_LOAD
    mov word [dap_segment], 0x0000
    mov dword [dap_lba], STAGE2_LBA
    mov dword [dap_lba+4], 0

    mov si, dap
    mov ah, 0x42
    mov dl, [boot_drv]
    int 0x13
    jc error

    ; 检查魔数
    cmp dword [STAGE2_LOAD], STAGE2_MAGIC
    jne error

    ; 跳 stage2，跳过魔数
    mov dl, [boot_drv]
    jmp 0x0000:(STAGE2_LOAD + 4)

error:
    mov si, msg_err
    mov ah, 0x0E
.loop:
    lodsb
    or al, al
    jz .halt
    int 0x10
    jmp .loop
.halt:
    hlt
    jmp .halt

msg_err  db 'stage1: boot error', 13, 10, 0
boot_drv db 0

dap:
    db 0x10, 0
dap_count:
    dw 0
dap_offset:
    dw 0
dap_segment:
    dw 0
dap_lba:
    dd 0
    dd 0

times 446-($-$$) db 0
times 64 db 0
times 510-($-$$) db 0
dw 0xAA55