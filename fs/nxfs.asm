; NXFS 文件读取
; 根目录在 LBA 2049, 每项 32 字节
;   偏移 0   11B  8.3 文件名
;   偏移 11  1B   属性
;   偏移 16  4B   起始 LBA
;   偏移 20  4B   文件大小
; 调用: SI=11B 文件名, ES:BX=目标缓冲, CF=1 未找到

nxfs_read_file:
    push ax
    push cx
    push dx
    push si
    push di
    push bx
    mov dx,si
    push es
    mov ax,ds
    mov es,ax
    mov eax,2049
    mov si,diskbuf
    mov cx,1
    call read_lba
    pop es
    jc .nrf_e
    mov di,diskbuf
    mov cx,16
.nrf_loop:
    push cx
    push di
    push si
    mov si,dx
    mov di,[esp+2]
    mov cx,11
.nrf_cmp:
    mov al,[si]
    cmp al,[di]
    jne .nrf_no
    inc si
    inc di
    loop .nrf_cmp
    pop si
    pop di
    pop cx
    mov eax,[di+16]
    mov ecx,[di+20]
    add ecx,511
    shr ecx,9
    mov si,0
    call read_lba
    jc .nrf_e
    pop bx
    pop di
    pop si
    pop dx
    pop cx
    pop ax
    clc
    ret
.nrf_no:
    pop si
    pop di
    pop cx
    add di,32
    loop .nrf_loop
    pop bx
    pop di
    pop si
    pop dx
    pop cx
    pop ax
    stc
    ret
.nrf_e:
    pop bx
    pop di
    pop si
    pop dx
    pop cx
    pop ax
    stc
    ret