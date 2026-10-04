; 命令行 shell + 内置命令

shell_loop:
    mov si,prompt
    call print
    mov di,cmdline
    call read_line
    call newline
    mov si,cmdline
    call skip_spaces
    cmp byte [si],0
    je shell_loop

    mov di,cmd_dir
    call match_cmd
    jc do_dir
    mov di,cmd_cls
    call match_cmd
    jc do_cls
    mov di,cmd_ver
    call match_cmd
    jc do_ver
    mov di,cmd_help
    call match_cmd
    jc do_help
    mov di,cmd_run
    call match_cmd
    jc do_run
    mov di,cmd_type
    call match_cmd
    jc do_type
    mov di,cmd_pmode
    call match_cmd
    jc do_pmode
    mov di,cmd_install
    call match_cmd
    jc do_install
    call try_run
    jc shell_loop
    mov si,msg_unknown
    call print
    jmp shell_loop

do_dir:
    call list_dir
    jmp shell_loop
do_cls:
    mov ax,0x0003
    int 0x10
    jmp shell_loop
do_ver:
    mov si,msg_ver
    call print
    jmp shell_loop
do_help:
    mov si,msg_help
    call print
    jmp shell_loop
do_run:
    call skip_spaces
    call try_run
    jc shell_loop
    mov si,msg_nofile
    call print
    jmp shell_loop
do_type:
    call skip_spaces
    call type_file
    jmp shell_loop
do_pmode:
    call pmode
    jmp shell_loop
do_install:
    call install_os
    jmp shell_loop

; match_cmd: SI=输入, DI=命令名, CF=1 匹配
match_cmd:
    push si
    push di
.mc_loop:
    mov al,[si]
    mov ah,[di]
    cmp ah,0
    je .mc_ew
    cmp al,ah
    jne .mc_no
    inc si
    inc di
    jmp .mc_loop
.mc_ew:
    mov al,[si]
    cmp al,' '
    je .mc_yes
    cmp al,0
    je .mc_yes
    cmp al,13
    je .mc_yes
.mc_no:
    clc
    pop di
    pop si
    ret
.mc_yes:
    stc
    pop di
    pop si
    ret

; read_line: DI=缓冲, 回车结束, 上限 63 字符
read_line:
    push ax
    push cx
.rl_loop:
    call check_ctrlc
    jc .rl_cc
    mov ah,0
    int 0x16
    cmp al,13
    je .rl_done
    cmp al,8
    je .rl_bs
    mov cx,di
    sub cx,cmdline
    cmp cx,63
    jge .rl_loop
    cmp al,'a'
    jl .rl_st
    cmp al,'z'
    jg .rl_st
    sub al,32
.rl_st:
    mov [di],al
    inc di
    mov ah,0x0E
    mov bx,7
    int 0x10
    jmp .rl_loop
.rl_bs:
    cmp di,cmdline
    jle .rl_loop
    dec di
    mov ah,0x0E
    mov al,8
    int 0x10
    mov al,' '
    int 0x10
    mov al,8
    int 0x10
    jmp .rl_loop
.rl_cc:
    mov si,msg_cc
    call print
    mov di,cmdline
    mov byte [di],0
    pop cx
    pop ax
    ret
.rl_done:
    mov byte [di],0
    pop cx
    pop ax
    ret

; skip_spaces: SI 跳过空格
skip_spaces:
    cmp byte [si],' '
    jne .ss_d
    inc si
    jmp skip_spaces
.ss_d:
    ret

; shell 字符串
banner  db 'NexDOS Version 1.0 (16-bit)',13,10
        db '(c) 2026 NexOS Project',13,10
        db 'no-emulation boot OK',13,10
        db 'Type HELP for commands.',13,10,13,10,0
prompt  db 'A:\> ',0
cmd_dir    db 'DIR',0
cmd_cls    db 'CLS',0
cmd_ver    db 'VER',0
cmd_help   db 'HELP',0
cmd_run    db 'RUN',0
cmd_type   db 'TYPE',0
cmd_pmode  db 'PMODE',0
cmd_install db 'INSTALL',0
msg_ver     db 'NexDOS 1.0',13,10,0
msg_unknown db 'Bad command or file name.',13,10,0
msg_cc      db '^C',13,10,0
msg_help db 'Commands:',13,10
         db '  DIR        List files',13,10
         db '  TYPE X     Show file',13,10
         db '  RUN X      Run program',13,10
         db '  PMODE      16->32-bit switch',13,10
         db '  INSTALL    Setup NexOS',13,10
         db '  CLS        Clear screen',13,10
         db '  VER        Version',13,10
         db '  HELP       Help',13,10,0