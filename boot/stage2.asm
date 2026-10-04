; NexOS - Stage2 Bootloader
; 设置 VBE 图形模式，读取内核，进入保护模式
org 0x0800
bits 16

VBE_INFO  equ 0x7000
MODE_INFO equ 0x7200

stage2_start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [boot_drive], dl
    mov al, '1'
    call putc

    ; 获取 VBE 信息
    mov ax, 0x4F00
    mov di, VBE_INFO
    int 0x10
    cmp ax, 0x004F
    jne vbe_fail

    mov al, '2'
    call putc

    ; 遍历模式列表，尝试设置
    mov word [mode_idx], 0
try_next:
    mov si, mode_list
    add si, [mode_idx]
    mov ax, [si]         ; 模式号
    cmp ax, 0
    je vbe_fail

    ; 先获取该模式的信息 (设置之前调用)
    mov cx, ax
    xor ax, ax
    mov es, ax
    mov di, MODE_INFO
    mov ax, 0x4F01
    int 0x10
    cmp ax, 0x004F
    jne next_mode

    ; 检查 linear framebuffer 支持
    mov ax, [MODE_INFO]
    test ax, 0x0080
    jz next_mode

    ; 保存当前模式信息指针
    mov [cur_mode], si

    ; 设置模式 (linear framebuffer)
    mov si, [cur_mode]
    mov bx, [si]
    or bx, 0x4000
    mov ax, 0x4F02
    int 0x10
    cmp ax, 0x004F
    je mode_ok

next_mode:
    add word [mode_idx], 8
    jmp try_next

mode_ok:
    mov al, '3'
    call putc

    ; VBE 模式设置成功后，给 VGA PCI BAR0 编程帧缓冲地址
    mov dx, 0xCF8
    mov eax, 0x80000000 | (0 << 16) | (2 << 11) | (0 << 8) | 0x10
    out dx, eax
    mov dx, 0xCFC
    mov eax, 0xE0000000
    out dx, eax
    mov dword [fb_addr], 0xE0000000

    ; 从结构体获取 width, height, bpp
    mov si, [cur_mode]
    mov ax, [si+2]       ; width
    mov [fb_width], ax
    mov ax, [si+4]       ; height
    mov [fb_height], ax
    mov ax, [si+6]       ; bpp
    mov [fb_bpp], ax

    ; 计算 pitch = width * bpp / 8
    mov ax, [fb_width]
    mov cx, [fb_bpp]
    mul cx               ; dx:ax = width * bpp
    mov cx, 8
    div cx               ; ax = pitch
    mov [fb_pitch], ax

    mov al, '4'
    call putc

    ; ===== 读取内核到 0x10000 =====
    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    mov word [kernel_lba], 17
    mov word [kernel_count], 64

read_loop:
    cmp word [kernel_count], 0
    je read_done

    ; LBA 转 CHS
    mov ax, [kernel_lba]
    mov cx, 18
    xor dx, dx
    div cx
    mov cl, dl
    inc cl
    mov ch, al
    shr ch, 1
    mov dh, al
    and dh, 1

    xor ax, ax
    mov es, ax
    mov ax, 0x1000
    mov es, ax

    mov ax, 0x0201
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    inc word [kernel_lba]
    dec word [kernel_count]
    add bx, 512
    jnc read_loop
    mov ax, es
    add ax, 0x1000
    mov es, ax
    xor bx, bx
    jmp read_loop

read_done:
    mov al, '5'
    call putc

    ; 开启 A20
    in al, 0x92
    or al, 2
    out 0x92, al

    ; 进入保护模式
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp CODE_SEG:pm_entry

bits 32
pm_entry:
    mov ax, DATA_SEG
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov esp, 0x90000

    ; 传递帧缓冲信息到 0x8000
    mov eax, [fb_addr]
    mov [0x8000], eax
    movzx eax, word [fb_pitch]
    mov [0x8004], eax
    movzx eax, word [fb_width]
    mov [0x8008], eax
    movzx eax, word [fb_height]
    mov [0x800C], eax
    movzx eax, word [fb_bpp]
    mov [0x8010], eax

    ; 复制内核到 0x100000
    mov esi, 0x10000
    mov edi, 0x100000
    mov ecx, 32768 / 4
    rep movsd

    jmp CODE_SEG:0x100000

.hang:
    hlt
    jmp .hang

bits 16
putc:
    push ax
    push bx
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    pop bx
    pop ax
    ret

vbe_fail:
    mov al, 'V'
    call putc
    jmp $

disk_error:
    mov al, 'D'
    call putc
    jmp $

; ===== 数据 =====
boot_drive   db 0x80
kernel_lba   dw 17
kernel_count dw 64
mode_idx     dw 0
cur_mode     dw 0

fb_addr   dd 0
fb_pitch  dw 0
fb_width  dw 0
fb_height dw 0
fb_bpp    dw 0

; 模式列表: 模式号(2), width(2), height(2), bpp(2)
mode_list:
    dw 0x143, 800, 600, 32
    dw 0x141, 640, 480, 32
    dw 0x115, 800, 600, 24
    dw 0x112, 640, 480, 24
    dw 0x114, 800, 600, 16
    dw 0x111, 640, 480, 16
    dw 0, 0, 0, 0

; GDT
gdt_start:
    dd 0x0, 0x0
gdt_code:
    dw 0xFFFF, 0x0
    db 0x0, 0b10011010, 0b11001111, 0x0
gdt_data:
    dw 0xFFFF, 0x0
    db 0x0, 0b10010010, 0b11001111, 0x0
gdt_end:
gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start
CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

; 填充到 8KB
times 8192 - ($ - $$) db 0
