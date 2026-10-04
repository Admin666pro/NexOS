; 分区、格式化、复制

; do_partition: 写 MBR (引导代码 + 分区表), NXFS 类型 0x66
do_partition:
    push ax
    push cx
    push si
    push di
    push es
    mov bx,ds
    mov es,bx
    mov si,hdboot_bin
    mov di,diskbuf
    mov cx,446
    rep movsb
    mov byte [diskbuf+446],0x80
    mov byte [diskbuf+450],0x66
    mov dword [diskbuf+454],2048
    mov eax,[hd_sectors]
    sub eax,2048
    mov [diskbuf+458],eax
    mov word [diskbuf+510],0xAA55
    mov eax,0
    mov si,diskbuf
    mov cx,1
    push es
    mov bx,ds
    mov es,bx
    call write_lba
    pop es
    pop es
    pop si
    pop di
    pop cx
    pop ax
    ret

; do_format: 写 NXFS 超级块 + 空根目录 (32 扇区全零)
do_format:
    push ax
    push cx
    push si
    push di
    push es
    mov bx,ds
    mov es,bx
    mov di,diskbuf
    mov cx,256
    xor ax,ax
    rep stosw
    mov word [diskbuf],'NX'
    mov word [diskbuf+2],'FS'
    mov byte [diskbuf+4],1
    mov dword [diskbuf+6],33
    mov dword [diskbuf+10],32
    mov dword [diskbuf+14],1
    mov eax,2048
    mov si,diskbuf
    mov cx,1
    push es
    mov bx,ds
    mov es,bx
    call write_lba
    pop es
    mov eax,2049
    mov cx,32
.df_l:
    push eax
    push cx
    mov si,diskbuf
    mov cx,1
    push es
    mov bx,ds
    mov es,bx
    call write_lba
    pop es
    pop cx
    pop eax
    jc .df_e
    inc eax
    loop .df_l
    clc
    pop es
    pop si
    pop di
    pop cx
    pop ax
    ret
.df_e:
    stc
    pop es
    pop si
    pop di
    pop cx
    pop ax
    ret

; do_copy: 复制内置文件到 NXFS 根目录
do_copy:
    push ax
    push cx
    push si
    push di
    push es
    mov bx,ds
    mov es,bx
    ; 准备根目录缓冲
    mov di,diskbuf
    mov cx,256
    xor ax,ax
    rep stosw
    ; 目录项 1: HELLO.C0W
    mov si,fn_hello
    mov di,diskbuf
    mov cx,11
    rep movsb
    mov byte [diskbuf+11],1
    mov dword [diskbuf+16],2048+33
    mov eax,19
    add eax,hello_size
    mov [diskbuf+20],eax
    ; 目录项 2: README.TXT
    mov si,fn_readme
    mov di,diskbuf+32
    mov cx,11
    rep movsb
    mov byte [diskbuf+43],2
    mov dword [diskbuf+48],2048+34
    mov eax,readme_size
    mov [diskbuf+52],eax
    ; 目录项 3: TAOHUA.TXT
    mov si,fn_taohua
    mov di,diskbuf+64
    mov cx,11
    rep movsb
    mov byte [diskbuf+75],2
    mov dword [diskbuf+80],2048+35
    mov dword [diskbuf+84],4096
    ; 目录项 4: WALL.BIN
    mov si,fn_wall
    mov di,diskbuf+96
    mov cx,11
    rep movsb
    mov byte [diskbuf+107],2
    mov dword [diskbuf+112],2048+43
    mov dword [diskbuf+116],65536
    ; 写根目录
    mov eax,2049
    mov si,diskbuf
    mov cx,1
    push es
    mov bx,0x0840
    mov es,bx
    call write_lba
    pop es
    jc .cp_e
    ; 清文件名区, 画 HELLO 提示
    mov word [txt_x],24
    mov word [txt_y],56
    mov al,0x01
    mov cx,24
    mov dx,56
    mov bx,300
    mov si,72
    call fill_rect
    mov si,ow_file_hello
    call draw_text
    mov ax,0
    call oobe_prog
    ; 写 HELLO.C0W 数据
    mov di,diskbuf
    mov cx,256
    xor ax,ax
    rep stosw
    mov si,hdr_c0w
    mov di,diskbuf
    mov cx,19
    rep movsb
    mov si,hello_code
    mov cx,hello_size
    rep movsb
    mov eax,2048+33
    mov si,diskbuf
    mov cx,1
    push es
    mov bx,0x0840
    mov es,bx
    call write_lba
    pop es
    jc .cp_e
    mov ax,5
    call oobe_prog
    ; README.TXT
    mov word [txt_x],24
    mov word [txt_y],56
    mov al,0x01
    mov cx,24
    mov dx,56
    mov bx,300
    mov si,72
    call fill_rect
    mov si,ow_file_readme
    call draw_text
    mov di,diskbuf
    mov cx,256
    xor ax,ax
    rep stosw
    mov si,readme_code
    mov cx,readme_size
    rep movsb
    mov eax,2048+34
    mov si,diskbuf
    mov cx,1
    push es
    mov bx,0x0840
    mov es,bx
    call write_lba
    pop es
    jc .cp_e
    mov ax,10
    call oobe_prog
    ; TAOHUA.TXT
    mov word [txt_x],24
    mov word [txt_y],56
    mov al,0x01
    mov cx,24
    mov dx,56
    mov bx,300
    mov si,72
    call fill_rect
    mov si,ow_file_taohua
    call draw_text
    mov eax,2048+35
    mov si,0
    mov cx,8
    push es
    mov bx,0x4C26
    mov es,bx
    call write_lba
    pop es
    jc .cp_e
    mov ax,20
    call oobe_prog
    ; WALL.BIN
    mov word [txt_x],24
    mov word [txt_y],56
    mov al,0x01
    mov cx,24
    mov dx,56
    mov bx,300
    mov si,72
    call fill_rect
    mov si,ow_file_wall
    call draw_text
    mov ax,25
    call oobe_prog
    mov eax,2048+43
    mov si,0
    mov cx,128
    push es
    mov bx,0x4D26
    mov es,bx
.dc_wloop:
    movzx eax,si
    add eax,2048+43
    push cx
    mov cx,8
    call write_lba
    pop cx
    jc .dc_wdone
    sub cx,8
    jz .dc_wdone
    add si,8
    push ax
    push cx
    push dx
    mov ax,cx
    mov bx,25
    mul bx
    mov bx,128
    div bx
    mov bx,50
    sub bx,ax
    mov ax,bx
    call oobe_prog
    pop dx
    pop cx
    pop ax
    jmp .dc_wloop
.dc_wdone:
    pop es
    jc .cp_e
    mov ax,50
    call oobe_prog
    clc
    pop es
    pop di
    pop si
    pop cx
    pop ax
    ret
.cp_e:
    stc
    pop es
    pop di
    pop si
    pop cx
    pop ax
    ret

hdr_c0w db 'This Is A C0W Program'
fn_hello  db 'HELLO   C0W'
fn_readme db 'README  TXT'
fn_taohua db 'TAOHUA  TXT'
fn_wall   db 'WALL    BIN'