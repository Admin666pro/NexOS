; 磁盘 IO：封装 int 0x13 扩展读写

; read_lba: EAX=LBA, ES:SI=缓冲区, CX=扇区数, CF=1 失败
read_lba:
    push ax
    push bx
    push cx
    push dx
    push si
    mov word [dap_cnt],cx
    mov word [dap_off],si
    mov bx,es
    mov word [dap_seg],bx
    mov dword [dap_lba],eax
    mov dl,[hd_num]
    mov ah,0x42
    mov si,dap
    push es
    mov bx,ds
    mov es,bx
    int 0x13
    pop es
    jc .re
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.re:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

; write_lba: EAX=LBA, ES:SI=缓冲区, CX=扇区数, CF=1 失败
write_lba:
    push ax
    push bx
    push cx
    push dx
    push si
    mov word [dap_cnt],cx
    mov word [dap_off],si
    mov bx,es
    mov word [dap_seg],bx
    mov dword [dap_lba],eax
    mov dl,[hd_num]
    mov ah,0x43
    mov si,dap
    push es
    mov bx,ds
    mov es,bx
    int 0x13
    pop es
    jc .we
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    clc
    ret
.we:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    stc
    ret

; detect_hd: 找第一个可用硬盘, 成功时 [hd_num]=盘号, CF=0
detect_hd:
    push ax
    push bx
    mov dl,0x80
.dh_l:
    mov ah,0x41
    mov bx,0x55AA
    int 0x13
    jc .dh_n
    cmp bx,0xAA55
    jne .dh_n
    mov [hd_num],dl
    pop bx
    pop ax
    clc
    ret
.dh_n:
    inc dl
    cmp dl,0x90
    jb .dh_l
    pop bx
    pop ax
    stc
    ret

; hd_has_system: 读 LBA 2049, 检查前 5 字节是否 "HELLO", CF=1 有系统
hd_has_system:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es
    mov si,hd_dap
    mov byte [si],0x10
    mov byte [si+1],0
    mov word [si+2],1
    mov word [si+4],0
    mov word [si+6],0x2000
    mov dword [si+8],2049
    mov dword [si+12],0
    mov ah,0x42
    mov dl,[boot_drv]
    int 0x13
    jc .hd_none
    mov ax,0x2000
    mov es,ax
    xor di,di
    mov cx,5
    mov si,sz_hello
    repe cmpsb
    jne .hd_none
    stc
    jmp .hd_done
.hd_none:
    clc
.hd_done:
    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

sz_hello db "HELLO"
hd_dap   times 16 db 0

; u32dec: EAX -> numbuf (十进制 ASCII, 结尾 0)
u32dec:
    push ax
    push bx
    push cx
    push dx
    push di
    mov di,numbuf
    mov cx,0
.ud_l:
    xor edx,edx
    mov ebx,10
    div ebx
    push dx
    inc cx
    test eax,eax
    jnz .ud_l
.ud_o:
    pop dx
    add dl,'0'
    mov [di],dl
    inc di
    loop .ud_o
    mov byte [di],0
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; show_hdinfo: 显示硬盘 CHS 参数 (文字模式)
show_hdinfo:
    push ax
    push bx
    push cx
    push dx
    mov dl,[hd_num]
    mov ah,0x08
    int 0x13
    movzx eax,ch
    movzx ebx,cl
    shr bl,6
    shl ebx,8
    add eax,ebx
    inc eax
    mov [hd_cyl],eax
    movzx ebx,dh
    inc ebx
    mov [hd_head],ebx
    movzx ebx,cl
    and ebx,0x3F
    mov [hd_spt],ebx
    mov eax,[hd_cyl]
    mov ebx,[hd_head]
    mul ebx
    mov ebx,[hd_spt]
    mul ebx
    mov [hd_sectors],eax
    mov ebx,2048
    div ebx
    mov [hd_mb],eax
    mov si,st_hd
    call draw_text
    movzx eax,byte [hd_num]
    call u32dec
    mov si,numbuf
    call draw_text
    call next_line
    mov si,st_cyl
    call draw_text
    mov eax,[hd_cyl]
    call u32dec
    mov si,numbuf
    call draw_text
    call next_line
    mov si,st_head
    call draw_text
    mov eax,[hd_head]
    call u32dec
    mov si,numbuf
    call draw_text
    call next_line
    mov si,st_spt
    call draw_text
    mov eax,[hd_spt]
    call u32dec
    mov si,numbuf
    call draw_text
    call next_line
    mov si,st_mb
    call draw_text
    mov eax,[hd_mb]
    call u32dec
    mov si,numbuf
    call draw_text
    pop dx
    pop cx
    pop bx
    pop ax
    ret

st_hd   db '检测到硬盘 ',0
st_cyl  db '柱面:',0
st_head db '磁头:',0
st_spt  db '每道扇区:',0
st_mb   db '容量(MB):',0