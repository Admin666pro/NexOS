; 内置虚拟文件系统 (内存表, 编译期绑定)
; vfs_table 每项 16B: 12B 名 + dw 偏移 + dw 大小

; list_dir: 列出所有 VFS 文件, 文本模式
list_dir:
    push si
    push cx
    mov si,vfs_table
    mov cx,[si]
    add si,2
.ld_loop:
    push cx
    mov cx,8
    mov di,si
.ld_nm:
    mov al,[di]
    cmp al,' '
    je .ld_mdone
    or al,al
    je .ld_mdone
    mov ah,0x0E
    mov bx,7
    int 0x10
    inc di
    loop .ld_nm
.ld_mdone:
    mov al,'.'
    mov ah,0x0E
    mov bx,7
    int 0x10
    mov di,si
    add di,8
    mov cx,3
.ld_ex:
    mov al,[di]
    inc di
    or al,al
    je .ld_exd
    cmp al,' '
    je .ld_exd
    mov ah,0x0E
    mov bx,7
    int 0x10
.ld_exd:
    loop .ld_ex
    call newline
    add si,16
    pop cx
    loop .ld_loop
    pop cx
    pop si
    ret

; try_run: SI=文件名, CF=1 已找到并执行, CF=0 未找到
try_run:
    push si
    push di
    push cx
    mov di,searchname
    mov cx,8
    call fill_name_field
    mov byte [di],'C'
    mov byte [di+1],'0'
    mov byte [di+2],'W'
    mov si,vfs_table
    mov cx,[si]
    add si,2
.tr_loop:
    push cx
    push si
    mov di,searchname
    mov cx,11
.tr_cmp:
    mov al,[di]
    cmp al,[si]
    jne .tr_no
    inc si
    inc di
    loop .tr_cmp
    pop si
    mov ax,[si+12]
    call ax
    pop cx
    pop cx
    pop di
    pop si
    stc
    ret
.tr_no:
    pop si
    add si,16
    pop cx
    loop .tr_loop
    pop cx
    pop di
    pop si
    clc
    ret

; type_file: SI=文件名, 显示文件内容, 找不到打印 msg_nofile
type_file:
    push si
    push di
    push cx
    mov di,searchname
    mov cx,8
    call fill_name_field
    mov byte [di],'T'
    mov byte [di+1],'X'
    mov byte [di+2],'T'
    mov si,vfs_table
    mov cx,[si]
    add si,2
.tf_loop:
    push cx
    push si
    mov di,searchname
    mov cx,11
.tf_cmp:
    mov al,[di]
    cmp al,[si]
    jne .tf_no
    inc si
    inc di
    loop .tf_cmp
    pop si
    mov si,[si+12]
    call print
    pop cx
    pop cx
    pop di
    pop si
    ret
.tf_no:
    pop si
    add si,16
    pop cx
    loop .tf_loop
    mov si,msg_nofile
    call print
    pop cx
    pop di
    pop si
    ret

; fill_name_field: SI=输入名, DI=输出, CX=字段长度 (8 或 3)
; 8.3 填充: 遇 '.' / 0 / ' ' 停止, 小写转大写, 剩余填空格
fill_name_field:
.fn_loop:
    mov al,[si]
    cmp al,'.'
    je .fn_pad
    cmp al,0
    je .fn_pad
    cmp al,' '
    je .fn_pad
    cmp al,'a'
    jl .fn_u
    cmp al,'z'
    jg .fn_u
    sub al,32
.fn_u:
    mov [di],al
    inc di
    inc si
    dec cx
    jnz .fn_loop
    ret
.fn_pad:
    mov al,' '
.fn_pl:
    mov [di],al
    inc di
    dec cx
    jnz .fn_pl
    ret

; 内置程序 (被 VFS 表引用)
hello_code:
    mov si,hello_msg
    call print
    ret
hello_msg  db 'Hello from NexDOS C0W!',13,10,0
hello_size equ $ - hello_code

readme_code:
    db 'Welcome to NexDOS v1.0!',13,10
    db '16-bit kernel at segment 0x0840.',13,10
    db 'Type PMODE to switch to 32-bit.',13,10,0
readme_size equ $ - readme_code

; VFS 表
vfs_table:
    dw 2
    db 'HELLO   C0W',0
    dw hello_code
    dw hello_size
    db 'README  TXT',0
    dw readme_code
    dw readme_size

msg_nofile db 'File not found.',13,10,0