; 16 位实模式 -> 32 位保护模式 -> 回到 16 位 -> int 0x19 重启

pmode:
    cli
    mov si,msg_pmode
    call print
    call newline
    mov [saved_sp],sp
    lgdt [gdtr]
    mov eax,cr0
    or eax,1
    mov cr0,eax
    jmp dword 0x18:pm32start

[bits 32]
pm32start:
    mov ax,0x20
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov esp,0x90000
    mov edi,0xB8000
    mov esi,msg32addr
    mov ecx,msg32len
.p:
    lodsb
    mov [edi],al
    mov byte [edi+1],0x1E
    add edi,2
    loop .p
    mov esi,msg32addr2
    mov ecx,msg32len2
.p2:
    lodsb
    mov [edi],al
    mov byte [edi+1],0x1F
    add edi,2
    loop .p2
    jmp dword 0x08:return_to_real

[bits 16]
return_to_real:
    mov eax,cr0
    and eax,0xFFFFFFFE
    mov cr0,eax
    jmp 0x0840:pm16_back

pm16_back:
    mov ax,0x0840
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov sp,0xFFF0
    lidt [idtr_real]
    sti
    mov si,msg_restart
    call print
    mov ah,0
    int 0x16
    int 0x19
.pm_hang:
    hlt
    jmp .pm_hang

msg_pmode   db 'Switching to 32-bit protected mode...',13,10,0
msg_restart db 'PMODE OK. Press any key to restart NexDOS...',13,10,0

; 32 位消息, 物理地址 = offset + 0x8400
msg32addr  equ msg32 + 0x8400
msg32      db 'PMODE OK: CPU now in 32-bit protected mode!',0
msg32len   equ $ - msg32
msg32addr2 equ msg32b + 0x8400
msg32b     db 'GDT loaded, CR0.PE set. Win98 logic works!',0
msg32len2  equ $ - msg32b

; GDT
gdt:
    dq 0
    ; 0x08 16 位代码, base 0x8400, limit 0xFFFF
    dw 0xFFFF
    dw 0x8400
    db 0x00
    db 0x9A
    db 0x00
    db 0x00
    ; 0x10 16 位数据, base 0, limit 0xFFFF
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x92
    db 0x00
    db 0x00
    ; 0x18 32 位代码, base 0x8400, 4K 粒度
    dw 0xFFFF
    dw 0x8400
    db 0x00
    db 0x9A
    db 0xCF
    db 0x00
    ; 0x20 32 位数据, flat
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x92
    db 0xCF
    db 0x00
gdt_end:
gdtr:
    dw gdt_end-gdt-1
    dd gdt + 0x8400