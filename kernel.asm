org 0x0000
bits 16

start:
cli
mov ax,0x0840
mov ds,ax
mov es,ax
mov ss,ax
mov sp,0xFFF0
sti
mov [boot_drv],dl
call kb_setup
%ifndef LIVE
call hd_has_system
jc .boot_desktop
call install_os
%endif
.boot_desktop:
mov si,banner
call print
call gui_main
jmp shell_loop

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

; ===== list_dir: 8.3 带点 =====
list_dir:
push si
push cx
mov si,vfs_table
mov cx,[si]
add si,2
ld_loop:
push cx
mov cx,8
mov di,si
ld_nm:
mov al,[di]
cmp al,' '
je ld_mdone
or al,al
je ld_mdone
mov ah,0x0E
mov bx,7
int 0x10
inc di
loop ld_nm
ld_mdone:
mov al,'.'
mov ah,0x0E
mov bx,7
int 0x10
mov di,si
add di,8
mov cx,3
ld_ex:
mov al,[di]
inc di
or al,al
je ld_exd
cmp al,' '
je ld_exd
mov ah,0x0E
mov bx,7
int 0x10
ld_exd:
loop ld_ex
call newline
add si,16
pop cx
loop ld_loop
pop cx
pop si
ret

; ===== try_run: SI=name, CF=1 found =====
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
tr_loop:
push cx
push si
mov di,searchname
mov cx,11
tr_cmp:
mov al,[di]
cmp al,[si]
jne tr_no
inc si
inc di
loop tr_cmp
pop si
mov ax,[si+12]
call ax
pop cx
pop cx
pop di
pop si
stc
ret
tr_no:
pop si
add si,16
pop cx
loop tr_loop
pop cx
pop di
pop si
clc
ret

; ===== type_file =====
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
tf_loop:
push cx
push si
mov di,searchname
mov cx,11
tf_cmp:
mov al,[di]
cmp al,[si]
jne tf_no
inc si
inc di
loop tf_cmp
pop si
mov si,[si+12]
call print
pop cx
pop cx
pop di
pop si
ret
tf_no:
pop si
add si,16
pop cx
loop tf_loop
mov si,msg_nofile
call print
pop cx
pop di
pop si
ret

; ===== pmode: 16位 -> 32位保护模式 -> 退回16位实模式 =====
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
; 切回16位代码段
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
pm_hang:
hlt
jmp pm_hang

; ===== match_cmd =====
match_cmd:
push si
push di
mc_loop:
mov al,[si]
mov ah,[di]
cmp ah,0
je mc_ew
cmp al,ah
jne mc_no
inc si
inc di
jmp mc_loop
mc_ew:
mov al,[si]
cmp al,' '
je mc_yes
cmp al,0
je mc_yes
cmp al,13
je mc_yes
mc_no:
clc
pop di
pop si
ret
mc_yes:
stc
pop di
pop si
ret

; ===== read_line =====
read_line:
push ax
push cx
rl_loop:
call check_ctrlc
jc rl_cc
mov ah,0
int 0x16
cmp al,13
je rl_done
cmp al,8
je rl_bs
mov cx,di
sub cx,cmdline
cmp cx,63
jge rl_loop
cmp al,'a'
jl rl_st
cmp al,'z'
jg rl_st
sub al,32
rl_st:
mov [di],al
inc di
mov ah,0x0E
mov bx,7
int 0x10
jmp rl_loop
rl_bs:
cmp di,cmdline
jle rl_loop
dec di
mov ah,0x0E
mov al,8
int 0x10
mov al,' '
int 0x10
mov al,8
int 0x10
jmp rl_loop
rl_cc:
mov si,msg_cc
call print
mov di,cmdline
mov byte [di],0
pop cx
pop ax
ret
rl_done:
mov byte [di],0
pop cx
pop ax
ret

; ===== skip_spaces =====
skip_spaces:
cmp byte [si],' '
jne ss_d
inc si
jmp skip_spaces
ss_d:
ret

; ===== fill_name_field =====
fill_name_field:
fn_loop:
mov al,[si]
cmp al,'.'
je fn_pad
cmp al,0
je fn_pad
cmp al,' '
je fn_pad
cmp al,'a'
jl fn_u
cmp al,'z'
jg fn_u
sub al,32
fn_u:
mov [di],al
inc di
inc si
dec cx
jnz fn_loop
ret
fn_pad:
mov al,' '
fn_pl:
mov [di],al
inc di
dec cx
jnz fn_pl
ret

; ===== print =====
print:
push ax
push bx
p_l:
lodsb
or al,al
jz p_d
mov ah,0x0E
mov bx,7
int 0x10
jmp p_l
p_d:
pop bx
pop ax
ret

; ===== newline =====
newline:
push ax
push bx
mov ah,0x0E
mov al,13
mov bx,7
int 0x10
mov al,10
int 0x10
pop bx
pop ax
ret

; ===== 内置程序 =====
hello_code:
mov si,hello_msg
call print
ret
hello_msg db 'Hello from NexDOS C0W!',13,10,0
hello_size equ $ - hello_code

readme_code:
db 'Welcome to NexDOS v1.0!',13,10
db '16-bit kernel at segment 0x0840.',13,10
db 'Type PMODE to switch to 32-bit.',13,10,0
readme_size equ $ - readme_code

; ===== 数据 =====
banner db 'NexDOS Version 1.0 (16-bit)',13,10
db '(c) 2026 NexOS Project',13,10
db 'no-emulation boot OK',13,10
db 'Type HELP for commands.',13,10,13,10,0
prompt db 'A:\> ',0
cmd_dir db 'DIR',0
cmd_cls db 'CLS',0
cmd_ver db 'VER',0
cmd_help db 'HELP',0
cmd_run db 'RUN',0
cmd_type db 'TYPE',0
cmd_pmode db 'PMODE',0
cmd_install db 'INSTALL',0
msg_ver db 'NexDOS 1.0',13,10,0
msg_unknown db 'Bad command or file name.',13,10,0
msg_cc db '^C',13,10,0
msg_nofile db 'File not found.',13,10,0
msg_help db 'Commands:',13,10
db '  DIR        List files',13,10
db '  TYPE X     Show file',13,10
db '  RUN X      Run program',13,10
db '  PMODE      16->32-bit switch',13,10
db '  INSTALL    Chinese setup (partition+NXFS)',13,10
db '  INSTALL    Copy NexDOS to HDD',13,10
db '  CLS        Clear screen',13,10
db '  VER        Version',13,10
db '  HELP       Help',13,10,0
msg_pmode db 'Switching to 32-bit protected mode...',13,10,0
dd 0
msg_restart db 'PMODE OK. Press any key to restart NexDOS...',13,10,0
boot_drv db 0
saved_sp dw 0
idtr_real:
dw 0x3FF
dd 0
cmdline times 64 db 0
searchname times 11 db 0
hdboot_bin:
incbin 'hdboot.bin'

; 32-bit messages (physical addr = offset + 0x8400)
msg32addr equ msg32 + 0x8400
msg32 db 'PMODE OK: CPU now in 32-bit protected mode!',0
msg32len equ $ - msg32
msg32addr2 equ msg32b + 0x8400
msg32b db 'GDT loaded, CR0.PE set. Win98 logic works!',0
msg32len2 equ $ - msg32b

; ===== GDT =====
gdt:
dq 0
; 0x08 code16: base 0x8400, limit 0xFFFF
dw 0xFFFF
dw 0x8400
db 0x00
db 0x9A
db 0x00
db 0x00
; 0x10 data16: base 0, limit 0xFFFF
dw 0xFFFF
dw 0x0000
db 0x00
db 0x92
db 0x00
db 0x00
; 0x18 code32: base 0x8400, limit 0xFFFFF, 4K gran, 32-bit
dw 0xFFFF
dw 0x8400
db 0x00
db 0x9A
db 0xCF
db 0x00
; 0x20 data32: base 0, flat
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

; ============================================================
; ===== hd_has_system: 硬盘已装 NXFS? 读根目录首项 HELLO, CF=1 有系统 =====
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
hd_dap times 16 db 0

; ============================================================
; ===== install_os: 图形化 OOBE 安装向导 (VGA 320x200) =====
; ============================================================
install_os:
call set_vga13
call mouse_init
call oobe_welcome
jc .io_exit
call oobe_hd
jc .io_exit
call oobe_partsel
jc .io_exit
cmp al,1
je .io_full
cmp al,2
je .io_fmt
jmp .io_copy
.io_full:
mov si,ow_stage_part
call oobe_stage
call do_partition
jc .io_wrerr
.io_fmt:
mov si,ow_stage_fmt
call oobe_stage
call do_format
jc .io_wrerr
.io_copy:
call oobe_copy
jc .io_wrerr
call oobe_done
.io_exit:
call set_text
ret
.io_wrerr:
call oobe_errpage
call set_text
ret

; ===== fill_rect: al=color, cx=x1, dx=y1, bx=x2, si=y2 =====
fill_rect:
push ax
push bx
push cx
push dx
push si
push di
mov di,bx
mov bx,dx
.fr_y:
mov dx,bx
push cx
.fr_x:
push ax
push dx
call put_pixel
pop dx
pop ax
inc cx
cmp cx,di
jbe .fr_x
pop cx
inc bx
cmp bx,si
jbe .fr_y
pop di
pop si
pop dx
pop cx
pop bx
pop ax
ret

; ===== oobe_win: si=标题, 全屏深蓝 (Win10 安装程序风格) =====
oobe_win:
push ax
push bx
push cx
push dx
mov [oobe_title_sv],si    ; 保存标题 (fill_rect 会覆盖 si)
mov al,0x01
mov cx,0
mov dx,0
mov bx,320
mov si,200
call fill_rect
mov al,0x0B
mov cx,0
mov dx,0
mov bx,320
mov si,26
call fill_rect
mov word [txt_x],14
mov word [txt_y],10
mov si,[oobe_title_sv]
mov byte [char_col],15
call draw_text
mov byte [char_col],7
pop dx
pop cx
pop bx
pop ax
ret

; ===== oobe_btn: si=文字, bl=1高亮, 按钮区 226,172-308,188 (蓝底白字) =====
oobe_btn:
push ax
push bx
push cx
push dx
mov [oobe_title_sv],si    ; 保存按钮文字 (fill_rect 会覆盖 si)
mov al,0x01
mov cx,224
mov dx,170
mov bx,310
mov si,190
call fill_rect
cmp bl,1
jne .ob_off
mov al,0x0B
jmp .ob_fill
.ob_off:
mov al,0x09
.ob_fill:
mov cx,226
mov dx,172
mov bx,308
mov si,188
call fill_rect
mov word [txt_x],244
mov word [txt_y],177
mov si,[oobe_title_sv]
mov byte [char_col],15    ; 按钮白字
call draw_text
mov byte [char_col],7
pop dx
pop cx
pop bx
pop ax
ret

; ===== oobe_input: 鼠标+键盘等待, 点击=Enter; 返回 AX 键值 =====
oobe_input:
.oi_loop:
call mouse_poll
call draw_cursor
mov al,[m_left]
cmp al,1
jne .oi_kb
cmp byte [m_prev],1
je .oi_loop
mov byte [m_prev],1
mov ax,0x0D
clc
ret
.oi_kb:
mov byte [m_prev],0
mov ah,1
int 0x16
jz .oi_loop
mov ah,0
int 0x16
ret

; ===== oobe_waitkey: Enter->CF=0, Esc->CF=1 =====
oobe_waitkey:
.owk:
call oobe_input
cmp al,0x1B
je .owk_esc
cmp al,0x0D
je .owk_ok
jmp .owk
.owk_esc:
stc
ret
.owk_ok:
clc
ret

; ===== oobe_stage: 工作页(窗口), si=阶段文字, wait_key =====
oobe_stage:
push si
mov si,ow_work_title
call oobe_win
pop si
mov word [txt_x],16
mov word [txt_y],60
call draw_text
call oobe_waitkey
ret

; ===== oobe_welcome: 欢迎页 =====
oobe_welcome:
mov si,ow_win_title
call oobe_win
mov word [txt_x],16
mov word [txt_y],44
mov si,ow_welcome
call draw_text
mov word [txt_x],16
mov word [txt_y],66
mov si,ow_wtext1
call draw_text
mov word [txt_x],16
mov word [txt_y],80
mov si,ow_wtext2
call draw_text
mov word [txt_x],16
mov word [txt_y],94
mov si,ow_hint
call draw_text
mov bl,1
mov si,btn_next
call oobe_btn
call oobe_waitkey
ret

; ===== oobe_hd: 硬盘检测页 =====
oobe_hd:
.oh_l:
mov si,ow_hd_title
call oobe_win
mov word [txt_x],16
mov word [txt_y],48
mov si,ow_detecting
call draw_text
call detect_hd
jc .oh_nohd
call show_hdinfo_oobe
mov bl,1
mov si,btn_next
call oobe_btn
call oobe_waitkey
ret
.oh_nohd:
mov word [txt_x],16
mov word [txt_y],70
mov si,ow_nohd1
call draw_text
mov word [txt_x],16
mov word [txt_y],86
mov si,ow_nohd2
call draw_text
mov bl,1
mov si,btn_retry
call oobe_btn
call oobe_waitkey
jnc .oh_l
stc
ret

; ===== show_hdinfo_oobe: 检测结果(窗口布局) =====
show_hdinfo_oobe:
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
mov word [txt_x],16
mov word [txt_y],68
mov si,ow_hd_ok
call draw_text
movzx eax,byte [hd_num]
call u32dec
mov si,numbuf
call draw_text
mov word [txt_y],84
mov si,ow_hd_cyl
call draw_text
mov eax,[hd_cyl]
call u32dec
mov si,numbuf
call draw_text
mov si,ow_comma
call draw_text
mov eax,[hd_head]
call u32dec
mov si,numbuf
call draw_text
mov si,ow_comma
call draw_text
mov eax,[hd_spt]
call u32dec
mov si,numbuf
call draw_text
mov word [txt_x],16
mov word [txt_y],100
mov si,ow_hd_mb
call draw_text
mov eax,[hd_mb]
call u32dec
mov si,numbuf
call draw_text
mov si,ow_mb
call draw_text
pop dx
pop cx
pop bx
pop ax
ret

; ===== oobe_partsel: 返回 al=1/2/3, Esc->CF=1 =====
oobe_partsel:
mov si,ow_sel_title
call oobe_win
mov byte [sel_cur],1
.ps_l:
mov word [txt_x],16
mov word [txt_y],40
mov si,ow_sel_ask
call draw_text
mov word [txt_y],120
mov si,ow_sel_key
call draw_text
mov word [txt_y],62
mov si,opt1
mov cx,1
call .ps_item
mov word [txt_y],80
mov si,opt2
mov cx,2
call .ps_item
mov word [txt_y],98
mov si,opt3
mov cx,3
call .ps_item
.ps_in:
call mouse_poll
call draw_cursor
mov al,[m_left]
cmp al,1
jne .ps_kb
cmp byte [m_prev],1
je .ps_kb
mov byte [m_prev],1
; 鼠标点击: 直接点选项行
mov ax,[m_x]
mov bx,[m_y]
cmp bx,62
jb .ps_in_ok
cmp bx,78
jb .ps_c1
cmp bx,80
jb .ps_in_ok
cmp bx,96
jb .ps_c2
cmp bx,98
jb .ps_in_ok
cmp bx,114
jb .ps_c3
jmp .ps_in_ok
.ps_c1:
mov byte [sel_cur],1
jmp .ps_ok
.ps_c2:
mov byte [sel_cur],2
jmp .ps_ok
.ps_c3:
mov byte [sel_cur],3
jmp .ps_ok
.ps_in_ok:
mov ax,0x0D00
jmp .ps_got
.ps_kb:
mov byte [m_prev],0
mov ah,1
int 0x16
jz .ps_in
mov ah,0
int 0x16
.ps_got:
cmp al,0x1B
je .ps_esc
cmp al,0x0D
je .ps_ok
cmp ah,0x48
jne .ps_k1
dec byte [sel_cur]
cmp byte [sel_cur],0
jg .ps_l
mov byte [sel_cur],1
jmp .ps_l
.ps_k1:
cmp ah,0x50
jne .ps_l
inc byte [sel_cur]
cmp byte [sel_cur],4
jl .ps_l
mov byte [sel_cur],3
jmp .ps_l
.ps_ok:
mov al,[sel_cur]
clc
ret
.ps_esc:
stc
ret

; ===== .ps_item: 画选项行(选中加'>'前缀), cx=选项号, si=文本, txt_y=行y =====
.ps_item:
push ax
push bx
push cx
push dx
push si
mov ax,[txt_y]
sub ax,2
mov dx,ax
add ax,16
mov si,ax
mov al,0x01
mov cx,12
mov bx,312
call fill_rect
pop si
cmp cl,[sel_cur]
jne .ps_it
mov word [txt_x],16
push si
mov si,ow_sel_mark
call draw_text
pop si
mov word [txt_x],28
call draw_text
jmp .ps_ix
.ps_it:
mov word [txt_x],16
call draw_text
.ps_ix:
pop dx
pop cx
pop bx
pop ax
ret

; ===== oobe_prog: ax=百分比(0-100), 进度条 18,86-302,102 =====
oobe_prog:
push ax
push bx
push cx
push dx
mov [ow_pct_cur],ax
mov al,0x0F
mov cx,18
mov dx,86
mov bx,302
mov si,102
call fill_rect
mov al,0x00
mov cx,20
mov dx,88
mov bx,300
mov si,100
call fill_rect
mov ax,[ow_pct_cur]
mov cx,ax
mov ax,280
mul cx
mov bx,100
div bx
mov dx,ax
add dx,20
mov al,0x02
mov cx,20
mov bx,dx
mov dx,88
mov si,100
call fill_rect
; 清百分比旧文字 (24,70)-(200,86)
mov al,0x01
mov cx,24
mov dx,70
mov bx,200
mov si,86
call fill_rect
mov word [txt_x],24
mov word [txt_y],70
mov si,ow_done_pct
call draw_text
movzx eax,word [ow_pct_cur]
call u32dec
mov si,numbuf
call draw_text
mov si,ow_pct
call draw_text
pop dx
pop cx
pop bx
pop ax
ret

; ===== oobe_copy: 复制文件页(含进度条) =====
oobe_copy:
mov si,ow_copy_title
call oobe_win
mov word [txt_x],16
mov word [txt_y],40
mov si,ow_copy_text
call draw_text
mov word [txt_x],16
mov word [txt_y],114
mov si,ow_copy_warn
call draw_text
call do_copy
jc .oc_e
mov ax,100
call oobe_prog
clc
ret
.oc_e:
stc
ret

; ===== oobe_done: 完成页 =====
oobe_done:
mov si,ow_done_title
call oobe_win
mov word [txt_x],16
mov word [txt_y],60
mov si,ow_done1
call draw_text
mov word [txt_x],16
mov word [txt_y],80
mov si,ow_done2
call draw_text
mov word [txt_x],16
mov word [txt_y],94
mov si,ow_done3
call draw_text
mov word [txt_x],16
mov word [txt_y],110
mov si,ow_rebooting
call draw_text
; 延迟让用户看到完成页
mov cx,0x3000
.dly1:
push cx
mov cx,0x3000
.dly2:
dec cx
jnz .dly2
pop cx
dec cx
jnz .dly1
int 0x19
ret

; ===== oobe_errpage: 写盘失败页 =====
oobe_errpage:
mov si,ow_err_title
call oobe_win
mov word [txt_x],16
mov word [txt_y],60
mov si,ow_err1
call draw_text
mov word [txt_x],16
mov word [txt_y],78
mov si,ow_err2
call draw_text
mov bl,1
mov si,btn_retry
call oobe_btn
call oobe_waitkey
ret

; ===== 图形模式切换 =====
set_vga13:
push ax
mov ax,0x0013
int 0x10
pop ax
ret
set_text:
push ax
mov ax,0x0003
int 0x10
pop ax
ret
clr_vga:
push ax
push cx
push di
push es
mov ax,0xA000
mov es,ax
xor di,di
mov cx,32000
xor ax,ax
rep stosw
pop es
pop di
pop cx
pop ax
ret

; ===== put_pixel: cx=x, dx=y, al=color (保存es,不破坏调用方段) =====
put_pixel:
push ax
push bx
push cx
push dx
push di
push es
push ax
mov ax,dx
mov bx,320
mul bx
add ax,cx
mov di,ax
pop ax
mov bx,0xA000
mov es,bx
mov [es:di],al
pop es
pop di
pop dx
pop cx
pop bx
pop ax
ret

; ===== draw_char_asc: cx=x, dx=y, ah=char (8x16) =====
draw_char_asc:
push ax
push bx
push cx
push dx
push si
push di
mov al,ah
xor ah,ah
shl ax,4
mov si,ax
mov bx,0x0B40
mov es,bx
mov bx,cx
mov di,16
.ac_r:
push di
push si
mov al,es:[si]
mov si,8
.ac_c:
push ax
push si
mov ah,al
test ah,0x80
jz .ac_nxt
mov ax,bx
mov cx,8
sub cx,si
add ax,cx
mov cx,ax
mov al,[char_col]
call put_pixel
.ac_nxt:
pop si
pop ax
shl al,1
dec si
jnz .ac_c
pop si
inc si
pop di
inc dx
dec di
jnz .ac_r
pop di
pop si
pop dx
pop cx
pop bx
pop ax
ret

; ===== draw_char_han: cx=x, dx=y, al=hi, ah=lo (16x16) =====
; 字库每行 2 字节: b1=左8px(b1 bit7=x0), b2=右8px(b2 bit7=x8)
; 读 word: al=b1, ah=b2; xchg 后 ax=b1<<8|b2, 逐位 shl ax 测 bit15=像素0
draw_char_han:
push ax
push bx
push cx
push dx
push si
push di
push bp
mov bx,cx
mov bp,dx
push ax
mov cl,al
xor ch,ch
sub cl,0xA1
mov ax,cx
mov cx,94
mul cx
mov cx,ax
pop ax
mov dl,ah
xor dh,dh
sub dl,0xA1
add cx,dx
mov ax,cx
shl ax,5
add ax,0x1000
mov si,ax
pushf
mov ax,cx
shr ax,11
popf
adc ax,0
shl ax,12
add ax,0x0B40
mov es,ax
mov di,16
.hn_r:
push di
push si
mov ax,es:[si]
xchg al,ah
mov si,16
.hn_c:
push ax
push si
test ah,0x80
jz .hn_nxt
mov cx,16
sub cx,si
mov ax,bx
add ax,cx
mov cx,ax
mov ax,bp
mov dx,16
sub dx,di
add ax,dx
mov dx,ax
mov al,[char_col]
call put_pixel
.hn_nxt:
pop si
pop ax
shl ax,1
dec si
jnz .hn_c
pop si
add si,2
pop di
dec di
jnz .hn_r
pop bp
pop di
pop si
pop dx
pop cx
pop bx
pop ax
ret

; ===== draw_text: si=GB2312串, 按txt_x/txt_y渲染 =====
draw_text:
push ax
push cx
push dx
push si
mov cx,[txt_x]
mov dx,[txt_y]
.dt_l:
lodsb
or al,al
jz .dt_d
cmp al,13
je .dt_nl
cmp al,10
je .dt_l
cmp al,0x20
jb .dt_l
cmp al,0x7F
jae .dt_han
mov ah,al
call draw_char_asc
add cx,8
jmp .dt_l
.dt_han:
mov ah,[si]
inc si
call draw_char_han
add cx,16
jmp .dt_l
.dt_nl:
mov word [txt_x],0
mov ax,[txt_y]
add ax,16
mov [txt_y],ax
mov cx,0
mov dx,ax
jmp .dt_l
.dt_d:
mov [txt_x],cx
mov [txt_y],dx
pop si
pop dx
pop cx
pop ax
ret

next_line:
push ax
mov ax,[txt_y]
add ax,16
mov [txt_y],ax
mov word [txt_x],0
pop ax
ret

; ===== detect_hd: 检测IDE/SATA硬盘 =====
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

; ===== show_hdinfo: 显示硬盘参数 =====
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

; ===== u32dec: eax -> numbuf (十进制) =====
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

wait_yn:
.wy:
mov ah,0
int 0x16
and al,0xDF
cmp al,'Y'
je .wy_y
cmp al,'N'
je .wy_n
jmp .wy
.wy_y:
mov al,'Y'
ret
.wy_n:
mov al,'N'
ret

wait_key:
mov ah,0
int 0x16
ret

; ===== do_partition: 写MBR引导代码+分区表 (NXFS type 0x66) =====
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

; ===== do_format: 写NXFS超级块+空根目录 =====
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

; ===== do_copy: 复制内置文件到NXFS =====
do_copy:
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
mov si,fn_hello
mov di,diskbuf
mov cx,11
rep movsb
mov byte [diskbuf+11],1
mov dword [diskbuf+16],2048+33
mov eax,19
add eax,hello_size
mov [diskbuf+20],eax
mov si,fn_readme
mov di,diskbuf+32
mov cx,11
rep movsb
mov byte [diskbuf+43],2
mov dword [diskbuf+48],2048+34
mov eax,readme_size
mov [diskbuf+52],eax
mov si,fn_taohua
mov di,diskbuf+64
mov cx,11
rep movsb
mov byte [diskbuf+75],2
mov dword [diskbuf+80],2048+35
mov dword [diskbuf+84],4096
mov si,fn_wall
mov di,diskbuf+96
mov cx,11
rep movsb
mov byte [diskbuf+107],2
mov dword [diskbuf+112],2048+43
mov dword [diskbuf+116],65536
mov eax,2049
mov si,diskbuf
mov cx,1
push es
mov bx,0x0840
mov es,bx
call write_lba
pop es
jc .cp_e
mov word [txt_x],24
mov word [txt_y],56
; 清旧文件名区
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
mov word [txt_x],24
mov word [txt_y],56
; 清旧文件名区
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
mov word [txt_x],24
mov word [txt_y],56
; 清旧文件名区
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
mov word [txt_x],24
mov word [txt_y],56
; 清旧文件名区
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

; ===== write_lba: AH=43h 写盘, eax=lba, si=buf(段=es), cx=count, CF=1 err =====
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

; ===== read_lba: AH=42h 读盘, eax=lba, si=buf(段=es), cx=count, CF=1 err =====
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

; ===== nxfs_read_file: SI=11B文件名, ES:BX=缓冲区, CF=1 未找到 =====
; 根目录 LBA 2049, 每项32B, 数据扇区从 [项+16] 起, 大小 [项+20]
nxfs_read_file:
push ax
push cx
push dx
push si
push di
push bx
mov dx,si
; 读根目录到 ds:diskbuf
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
; 匹配成功, di 仍为项首; 按 size 计算扇数
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

; ============================================================
; ===== NexOS 图形桌面 (Win98 风格) + PS/2 鼠标 =====
; ============================================================
gui_main:
call set_vga13
call gui_load_wall
jc .gm_nwall
call gui_draw_desktop
call mouse_init
call gui_loop
ret
.gm_nwall:
call clr_vga
call gui_draw_desktop
call mouse_init
call gui_loop
ret

; ===== gui_load_wall: 读硬盘 WALL.BIN -> 0x3000:0, 设DAC+写显存, CF=1 失败 =====
gui_load_wall:
push ax
push bx
push cx
push dx
push si
push di
push es
push ds
%ifndef LIVE
mov si,fn_wall
mov ax,0x3000
mov es,ax
mov bx,0
call nxfs_read_file
jnc .gw_have
%endif
; live/fallback: WALL 数据在 0x4D26:0 (调色板768+像素64000)
mov ax,0x4D26
mov es,ax
.gw_have:
; 调色板 768B -> DAC (3C8/3C9)
mov dx,0x3C8
xor al,al
out dx,al
mov dx,0x3C9
mov si,0
mov cx,768
.gw_pal:
mov al,[es:si]
out dx,al
inc si
loop .gw_pal
; 像素 64000B 源段=es -> 0xA000:0
mov ax,es
mov ds,ax
mov ax,0xA000
mov es,ax
mov si,768
xor di,di
mov cx,32000
rep movsw
clc
jmp .gw_done
.gw_fail:
stc
.gw_done:
pop ds
pop es
pop di
pop si
pop dx
pop cx
pop bx
pop ax
ret

; ----- 桌面背景 + 图标 + 任务栏 -----
gui_draw_desktop:
push ax
push bx
push cx
push dx
push si
push di
; 背景: 壁纸已由 gui_load_wall 写入, 失败路径用 clr_vga 蓝底
; 图标: 我的电脑/控制面板/桃花源记/NexDOS (16x16 色块 + 文字)
mov cx,4
mov dx,4
mov al,0x09
call draw_icon
mov word [txt_x],8
mov word [txt_y],28
mov si,g_mycomp_l
call draw_text
mov cx,84
mov dx,4
mov al,0x0E
call draw_icon
mov word [txt_x],88
mov word [txt_y],28
mov si,g_cpanel_l
call draw_text
mov cx,164
mov dx,4
mov al,0x02
call draw_icon
mov word [txt_x],168
mov word [txt_y],28
mov si,g_book_l
call draw_text
mov cx,244
mov dx,4
mov al,0x04
call draw_icon
mov word [txt_x],248
mov word [txt_y],28
mov si,g_dos_l
call draw_text
; 任务栏: y=184..199 灰
mov ax,0xA000
mov es,ax
mov di,184*320
mov cx,16*320
mov al,0x07
.tbl:
mov [es:di],al
inc di
dec cx
jnz .tbl
; 开始按钮: 蓝底 (0,184)-(47,199)
mov di,184*320
mov cx,16
.stb:
push cx
mov cx,48
mov al,0x09
.stbx:
mov [es:di],al
inc di
dec cx
jnz .stbx
sub di,48
add di,320
pop cx
dec cx
jnz .stb
; 开始文字
mov word [txt_x],6
mov word [txt_y],184
mov si,g_start
call draw_text
; 任务栏右侧 "NexOS 1.0"
mov word [txt_x],250
mov word [txt_y],184
mov si,g_ver
call draw_text
; 关机小按钮 (292,184)-(319,199)
mov di,184*320+292
mov cx,16
.shb:
push cx
mov cx,28
mov al,0x04
.shbx:
mov [es:di],al
inc di
dec cx
jnz .shbx
sub di,28
add di,320
pop cx
dec cx
jnz .shb
mov word [txt_x],294
mov word [txt_y],184
mov si,g_power
call draw_text
pop di
pop si
pop dx
pop cx
pop bx
pop ax
ret

; ----- 主循环: 鼠标轮询 + 光标 + 点击 -----
gui_loop:
call mouse_poll
call draw_cursor
; 点击检测: left 0->1
mov al,[m_left]
cmp al,[m_prev]
je .gl2
cmp al,1
jne .gl2
call gui_click
.gl2:
mov al,[m_left]
mov [m_prev],al
; Ctrl+C -> CLI
call check_ctrlc
jc gui_to_dos
; 键盘: Esc -> CLI
mov ah,1
int 0x16
jz .gl3
mov ah,0
int 0x16
cmp al,27
jne .gl3
call gui_to_dos
.gl3:
jmp gui_loop

gui_to_dos:
mov ax,0x0003
int 0x10
jmp shell_loop

; ----- 点击处理: 按 (mx,my) 命中区域 -----
gui_click:
push ax
push bx
mov ax,[m_x]
mov bx,[m_y]
; 我的电脑: 0-79, 0-51
cmp bx,52
jae .c1
cmp ax,80
jae .c1
call gui_mycomp
jmp .cdone
.c1:
; 控制面板: 80-159
cmp bx,52
jae .c2
cmp ax,160
jae .c2
cmp ax,80
jb .c2
call gui_cpanel
jmp .cdone
.c2:
; 桃花源记: 160-239
cmp bx,52
jae .c3
cmp ax,240
jae .c3
cmp ax,160
jb .c3
call gui_book
jmp .cdone
.c3:
; 重启NexDOS: 240-319
cmp bx,52
jae .c4
cmp ax,240
jb .c4
call gui_to_dos
jmp .cdone
.c4:
; 关机按钮: 292-319, 184-199
cmp bx,184
jb .cdone
cmp bx,200
jae .cdone
cmp ax,292
jb .c5
mov ax,0x0003
int 0x10
mov si,g_shutdown
call print
cli
hlt
.c5:
; 开始按钮: 0-47, 184-199 -> 开始菜单
cmp ax,48
jae .cdone
call gui_start_menu
jmp .cdone
.cdone:
pop bx
pop ax
ret

; ----- 开始菜单: 弹出式, 全鼠标 -----
gui_start_menu:
push ax
push bx
push cx
push dx
push si
push di
; 菜单背景 (2,140)-(154,196) 灰
mov ax,0xA000
mov es,ax
mov di,140*320+2
mov cx,15
.gm_row:
push cx
mov cx,152
mov al,0x07
.gm_px:
mov [es:di],al
inc di
dec cx
jnz .gm_px
add di,320-152
pop cx
dec cx
jnz .gm_row
; 4 项文字 (每项 14px, 灰底黑字)
mov byte [char_col],0
mov word [txt_x],8
mov word [txt_y],142
mov si,g_dos_l
call draw_text
mov word [txt_x],8
mov word [txt_y],156
mov si,g_power
call draw_text
mov word [txt_x],8
mov word [txt_y],170
mov si,g_about_title
call draw_text
mov word [txt_x],8
mov word [txt_y],184
mov si,g_reinst_title
call draw_text
mov byte [char_col],7
; 菜单循环: 鼠标点击项执行, 点击菜单外/Esc 关闭
.gm_l:
call mouse_poll
call draw_cursor
mov al,[m_left]
cmp al,[m_prev]
je .gm_kb
cmp al,1
jne .gm_kb
mov ax,[m_x]
mov bx,[m_y]
cmp bx,140
jb .gm_close
cmp bx,196
jae .gm_close
cmp ax,2
jb .gm_close
cmp ax,154
jae .gm_close
cmp bx,154
jb .gm_nexdos
cmp bx,168
jb .gm_power
cmp bx,182
jb .gm_about
call sub_reinst
call gui_sub
jmp .gm_close
.gm_nexdos:
call gui_to_dos
jmp .gm_close
.gm_power:
mov ax,0x0003
int 0x10
mov si,g_shutdown
call print
cli
hlt
.gm_about:
call sub_about
call gui_sub
jmp .gm_close
.gm_kb:
mov al,[m_left]
mov [m_prev],al
mov ah,1
int 0x16
jz .gm_l
mov ah,0
int 0x16
cmp al,27
je .gm_close
jmp .gm_l
.gm_close:
call clr_vga
call gui_draw_desktop
pop di
pop si
pop dx
pop cx
pop bx
pop ax
ret

; ----- 页面: 标题栏+内容, 任意键/×/Esc 返回桌面 (鼠标可用) -----
gui_page:
push ax
call clr_vga
call gui_page_head
.wp:
call win_loop
call clr_vga
call gui_draw_desktop
pop ax
ret

; ===== 我的电脑: 硬盘信息 =====
gui_mycomp:
mov word [g_ptitle],0
mov si,g_pc_title
mov [g_ptitle],si
mov si,g_pc_info
mov [g_content],si
call gui_page
ret

; ===== 控制面板: 菜单, 鼠标点击或数字键选子页 =====
gui_cpanel:
mov word [g_ptitle],0
mov si,g_cp_title
mov [g_ptitle],si
mov si,g_cp_menu
mov [g_content],si
.gcm_redraw:
call clr_vga
call gui_page_head
mov word [txt_x],4
mov word [txt_y],24
mov si,g_cp_menu
call draw_text
.gcm:
call mouse_poll
call draw_cursor
mov al,[m_left]
cmp al,[m_prev]
je .gcm_kb
cmp al,1
jne .gcm_kb
; 鼠标点击
mov ax,[m_x]
mov bx,[m_y]
cmp bx,16
jb .gcm_btn
cmp bx,40
jb .gcm_1
cmp bx,56
jb .gcm_2
cmp bx,72
jb .gcm_3
cmp bx,88
jb .gcm_4
jmp .gcm_kb2
.gcm_btn:
cmp ax,260
jae .gcm_done
jmp .gcm_kb2
.gcm_1:
call sub_show
call gui_sub
jmp .gcm_redraw
.gcm_2:
call sub_snd
call gui_sub
jmp .gcm_redraw
.gcm_3:
call sub_about
call gui_sub
jmp .gcm_redraw
.gcm_4:
call sub_reinst
call gui_sub
jmp .gcm_redraw
.gcm_kb:
mov al,[m_left]
mov [m_prev],al
mov ah,1
int 0x16
jz .gcm
mov ah,0
int 0x16
cmp al,27
je .gcm_done
cmp al,'1'
je .gcm_1
cmp al,'2'
je .gcm_2
cmp al,'3'
je .gcm_3
cmp al,'4'
je .gcm_4
jmp .gcm
.gcm_kb2:
mov al,[m_left]
mov [m_prev],al
jmp .gcm
.gcm_done:
call clr_vga
call gui_draw_desktop
ret

; ----- 子页: si=内容, 等键返回菜单 -----
gui_sub:
push ax
call clr_vga
call gui_page_head
mov word [txt_x],4
mov word [txt_y],24
mov si,[g_content]
call draw_text
mov word [txt_x],4
mov word [txt_y],184
mov si,g_anykey
call draw_text
.ws:
call win_loop
pop ax
ret

; 子页选择: 设标题+内容
sub_show:
mov si,g_cp_show
mov [g_content],si
mov si,g_show_title
mov [g_ptitle],si
ret
sub_snd:
mov si,g_cp_snd
mov [g_content],si
mov si,g_snd_title
mov [g_ptitle],si
ret
sub_about:
mov si,g_cp_about
mov [g_content],si
mov si,g_about_title
mov [g_ptitle],si
ret
sub_reinst:
mov si,g_cp_reinst
mov [g_content],si
mov si,g_reinst_title
mov [g_ptitle],si
ret

; ----- 画标题栏+内容头 (共用) -----
gui_page_head:
push ax
push bx
push cx
push dx
push si
push di
mov ax,0xA000
mov es,ax
mov di,0
mov cx,16
.ph:
push cx
mov cx,320
mov al,0x09
.phx:
mov [es:di],al
inc di
dec cx
jnz .phx
pop cx
dec cx
jnz .ph
; 标题栏控件: - [] x (右端)
mov di,260
mov cx,16
.bt_min:
push cx
mov cx,16
mov al,0x07
.bt_minx:
mov [es:di],al
inc di
dec cx
jnz .bt_minx
sub di,16
add di,320
pop cx
dec cx
jnz .bt_min
mov di,278
mov cx,16
.bt_max:
push cx
mov cx,16
mov al,0x07
.bt_maxx:
mov [es:di],al
inc di
dec cx
jnz .bt_maxx
sub di,16
add di,320
pop cx
dec cx
jnz .bt_max
mov di,296
mov cx,16
.bt_cls:
push cx
mov cx,16
mov al,0x04
.bt_clsx:
mov [es:di],al
inc di
dec cx
jnz .bt_clsx
sub di,16
add di,320
pop cx
dec cx
jnz .bt_cls
mov word [txt_x],298
mov word [txt_y],0
mov si,g_w_close
call draw_text
mov word [txt_x],280
mov word [txt_y],0
mov si,g_w_max
call draw_text
mov word [txt_x],262
mov word [txt_y],0
mov si,g_w_min
call draw_text
mov word [txt_x],4
mov word [txt_y],2
mov si,[g_ptitle]
call draw_text
mov word [txt_x],4
mov word [txt_y],24
mov si,[g_content]
test si,si
jz .ph_skip
call draw_text
.ph_skip:
pop di
pop si
pop dx
pop cx
pop bx
pop ax
ret

; ----- 窗口循环: 鼠标+光标+标题栏按钮+键盘 -----
; 返回: al=按键码; al=0xFF 表示关闭(Esc 或 点 x)
win_loop:
call mouse_poll
call draw_cursor
mov al,[m_left]
cmp al,[m_prev]
je .wl2
cmp al,1
jne .wl2
call win_click
cmp ax,1
jne .wl2
mov byte [m_prev],1
mov al,0xFF
ret
.wl2:
mov al,[m_left]
mov [m_prev],al
mov ah,1
int 0x16
jz .wl3
mov ah,0
int 0x16
cmp al,27
jne .wl_key
mov al,0xFF
ret
.wl_key:
ret
.wl3:
jmp win_loop

; ----- 标题栏按钮点击: -/[]/x 全部关闭窗口, 返回 ax=1 关闭, 否则 ax=0 -----
win_click:
mov ax,[m_x]
mov bx,[m_y]
cmp bx,16
jae .wc0
cmp ax,260
jae .wc_close
mov ax,0
ret
.wc_close:
mov ax,1
ret
.wc0:
mov ax,0
ret

; ===== 桃花源记: 全文分页 + 翻译 =====
gui_book:
mov word [g_ptitle],0
mov si,g_book_title
mov [g_ptitle],si
mov byte [g_bmode],0
mov byte [g_bpage],0
call book_load
jnc .book_ok
call clr_vga
mov word [txt_x],40
mov word [txt_y],90
mov si,g_book_err
call draw_text
mov word [txt_x],40
mov word [txt_y],120
mov si,g_anykey
call draw_text
.wb_err:
call win_loop
cmp al,0xFF
jne .wb_err
call clr_vga
call gui_draw_desktop
ret
.book_ok:
.book_loop:
call clr_vga
call gui_page_head
call book_set_content
call copy_page_to_buf
mov word [txt_x],4
mov word [txt_y],24
mov si,page_buf
call draw_text
; 底部按钮: 上一页/翻译/下一页/关闭 (全鼠标, 灰底黑字)
mov al,0x07
mov cx,4
mov dx,184
mov bx,60
mov si,199
call fill_rect
mov byte [char_col],0
mov word [txt_x],8
mov word [txt_y],186
mov si,g_btn_prev
call draw_text
mov al,0x07
mov cx,100
mov dx,184
mov bx,156
mov si,199
call fill_rect
mov word [txt_x],104
mov word [txt_y],186
mov si,g_btn_tr
call draw_text
mov al,0x07
mov cx,200
mov dx,184
mov bx,256
mov si,199
call fill_rect
mov word [txt_x],204
mov word [txt_y],186
mov si,g_btn_next
call draw_text
mov al,0x07
mov cx,276
mov dx,184
mov bx,316
mov si,199
call fill_rect
mov word [txt_x],280
mov word [txt_y],186
mov si,g_w_close
call draw_text
mov byte [char_col],7
.wb:
call mouse_poll
call draw_cursor
mov al,[m_left]
cmp al,[m_prev]
je .wb_kb
cmp al,1
jne .wb_kb
; 鼠标点击
mov ax,[m_x]
mov bx,[m_y]
cmp bx,16
jb .wb_btn
cmp bx,184
jae .wb_btns
jmp .wb_kb2
.wb_btn:
cmp ax,260
jae .book_done
jmp .wb_kb2
.wb_btns:
cmp ax,60
jb .book_prev
cmp ax,100
jb .wb_kb2
cmp ax,156
jb .book_toggle
cmp ax,200
jb .wb_kb2
cmp ax,256
jb .book_next
cmp ax,276
jb .wb_kb2
cmp ax,316
jbe .book_done
.wb_kb2:
mov al,[m_left]
mov [m_prev],al
jmp .wb_kb
.wb_kb:
mov al,[m_left]
mov [m_prev],al
mov ah,1
int 0x16
jz .wb
mov ah,0
int 0x16
cmp al,27
je .book_done
cmp al,'t'
je .book_toggle
cmp al,'T'
je .book_toggle
cmp al,' '
je .book_next
cmp al,13
je .book_next
cmp al,'p'
je .book_next
cmp al,'P'
je .book_next
cmp al,'b'
je .book_prev
cmp al,'B'
je .book_prev
cmp al,0
jne .wb
cmp ah,0x4D
je .book_next
cmp ah,0x4B
je .book_prev
jmp .wb
.book_next:
inc byte [g_bpage]
call book_bounds
jmp .book_loop
.book_prev:
dec byte [g_bpage]
call book_bounds
jmp .book_loop
.book_toggle:
xor byte [g_bmode],1
mov byte [g_bpage],0
jmp .book_loop
.book_done:
call clr_vga
call gui_draw_desktop
ret

; ===== book_load: 读硬盘 TAOHUA.TXT 到 0x2000:0, CF=1 失败 =====
book_load:
push ax
push si
push bx
push es
%ifndef LIVE
mov si,fn_taohua
mov ax,0x2000
mov es,ax
xor bx,bx
call nxfs_read_file
jnc .bt_ok
%endif
; live/fallback: TAOHUA 在 0x4C26:0, 复制 4096B 到 0x2000:0
push ds
push di
mov ax,0x4C26
mov ds,ax
mov ax,0x2000
mov es,ax
xor si,si
xor di,di
mov cx,2048
rep movsw
pop di
pop ds
.bt_ok:
pop es
pop bx
pop si
pop ax
ret

; 设置当前页内容: 计算页首行偏移 (段0x2000), g_bmode 0=原文 1=翻译
book_set_content:
push ax
push cx
push si
push di
push es
mov ax,0x2000
mov es,ax
xor si,si
cmp byte [g_bmode],0
je .bsc_find
.bsc_scan:
mov al,[es:si]
inc si
cmp al,0x0C
jne .bsc_scan
.bsc_find:
mov cl,[g_bpage]
xor ch,ch
.bsc_skip:
cmp cx,0
je .bsc_done
mov al,[es:si]
cmp al,0
je .bsc_done
cmp al,0x0C
je .bsc_done
cmp al,10
jne .bsc_next
dec cx
.bsc_next:
inc si
jmp .bsc_skip
.bsc_done:
mov [g_content],si
pop es
pop di
pop si
pop cx
pop ax
ret

; ===== copy_page_to_buf: 复制当前页 8 行到 page_buf (行间 13,10 结尾 0) =====
copy_page_to_buf:
push ax
push cx
push si
push di
push es
mov ax,0x2000
mov es,ax
mov si,[g_content]
mov di,page_buf
mov cx,8
.cpb_line:
push cx
.cpb_ch:
mov al,[es:si]
cmp al,0
je .cpb_eol
cmp al,0x0C
je .cpb_eol
cmp al,13
je .cpb_cr
mov [di],al
inc si
inc di
jmp .cpb_ch
.cpb_cr:
mov byte [di],13
inc di
mov byte [di],10
inc di
inc si
mov al,[es:si]
cmp al,10
jne .cpb_noskip
inc si
.cpb_noskip:
pop cx
dec cx
jz .cpb_done
jmp .cpb_line
.cpb_eol:
mov byte [di],0
inc di
.cpb_scan:
mov al,[es:si]
cmp al,0
je .cpb_eof
cmp al,0x0C
je .cpb_eof
cmp al,10
je .cpb_adv
inc si
jmp .cpb_scan
.cpb_adv:
inc si
pop cx
dec cx
jz .cpb_done
jmp .cpb_line
.cpb_eof:
pop cx
.cpb_done:
pop es
pop di
pop si
pop cx
pop ax
ret

; 页边界: 原文 0..4, 翻译 0..5, 环绕
book_bounds:
push ax
cmp byte [g_bmode],0
jne .bb_tr
cmp byte [g_bpage],0xFF
jne .bb_ok
mov byte [g_bpage],4
jmp .bb_done
.bb_ok:
cmp byte [g_bpage],5
jb .bb_done
mov byte [g_bpage],0
jmp .bb_done
.bb_tr:
cmp byte [g_bpage],0xFF
jne .bb_ok2
mov byte [g_bpage],5
jmp .bb_done
.bb_ok2:
cmp byte [g_bpage],6
jb .bb_done
mov byte [g_bpage],0
.bb_done:
pop ax
ret

; ----- 鼠标: PS/2 初始化 -----
mouse_init:
push ax
push cx
call kb_wait
mov al,0xA8
out 0x64,al
call kb_wait
mov al,0xD4
out 0x64,al
call kb_wait
mov al,0xF6
out 0x60,al
call mouse_ack
call kb_wait
mov al,0xD4
out 0x64,al
call kb_wait
mov al,0xF4
out 0x60,al
call mouse_ack
mov byte [mp_st],0
mov byte [m_left],0
mov byte [m_prev],0
pop cx
pop ax
ret

kb_wait:
push ax
push cx
mov cx,0xFFFF
.kw:
in al,0x64
test al,2
jz .kw_done
dec cx
jnz .kw
.kw_done:
pop cx
pop ax
ret

mouse_ack:
push ax
push cx
mov cx,0xFFFF
.ma:
in al,0x64
test al,1
jnz .ma_got
dec cx
jnz .ma
jmp .ma_done
.ma_got:
in al,0x60
.ma_done:
pop cx
pop ax
ret

; ----- 鼠标轮询: 读 3 字节包 -----
mouse_poll:
push ax
.mp:
in al,0x64
test al,0x20
jz .mpd
in al,0x60
cmp byte [mp_st],0
jne .mp1
test al,0x08
jz .mp
mov [mp_b0],al
mov byte [mp_st],1
jmp .mpd
.mp1:
cmp byte [mp_st],1
jne .mp2
mov [mp_xd],al
mov byte [mp_st],2
jmp .mpd
.mp2:
mov [mp_yd],al
mov byte [mp_st],0
; 应用增量
mov al,[mp_b0]
and al,1
mov [m_left],al
mov al,[mp_xd]
cbw
mov bx,ax
mov ax,[m_x]
add ax,bx
cmp ax,0
jge .mx1
mov ax,0
.mx1:
cmp ax,319
jle .mx2
mov ax,319
.mx2:
mov [m_x],ax
mov al,[mp_yd]
cbw
mov bx,ax
mov ax,[m_y]
sub ax,bx
cmp ax,0
jge .my1
mov ax,0
.my1:
cmp ax,199
jle .my2
mov ax,199
.my2:
mov [m_y],ax
.mpd:
pop ax
ret

; ----- 光标: 16x16 XOR (32 字节字形) -----
; 光标: 擦旧画新 (无拖影), 字形用内置 "↖"
draw_cursor:
push ax
push bx
push cx
push dx
push si
push di
push bp
cmp byte [cur_visible],0
je .draw_new
mov cx,[old_x]
mov dx,[old_y]
cmp cx,[m_x]
jne .do_erase
cmp dx,[m_y]
je .no_change
.do_erase:
call .core
.draw_new:
mov cx,[m_x]
mov dx,[m_y]
mov [old_x],cx
mov [old_y],dx
call .core
mov byte [cur_visible],1
pop bp
pop di
pop si
pop dx
pop cx
pop bx
pop ax
ret
.no_change:
pop bp
pop di
pop si
pop dx
pop cx
pop bx
pop ax
ret
.core:
push ds
mov ax,0xA000
mov es,ax
mov bx,cur_shape
mov di,0
.cy:
call check_ctrlc
jc .cx_exit
mov bp,cx
mov ax,dx
push dx
mov si,320
mul si
pop dx
add bp,ax
mov al,[bx+di]
mov ah,0x80
.cbit_l:
test al,ah
jz .cb_l0
xor byte [es:bp],0x0F
.cb_l0:
inc bp
shr ah,1
cmp ah,0
jne .cbit_l
mov al,[bx+di+1]
mov ah,0x80
.cbit_r:
test al,ah
jz .cb_r0
xor byte [es:bp],0x0F
.cb_r0:
inc bp
shr ah,1
cmp ah,0
jne .cbit_r
add di,2
inc dx
cmp di,32
jne .cy
pop ds
ret
.cx_exit:
pop ds
ret

; ===== 图形桌面数据 =====
g_mycomp db '我的电脑',0
g_mycomp_l db '我的电脑',0
g_cpanel db '控制面板',0
g_cpanel_l db '控制面板',0
g_book db '桃花源记',0
g_book_l db '桃花源记',0
g_dos db 'NexDOS',0
g_dos_l db 'NexDOS',0
g_start db '开始',0
g_ver db 'NexOS 1.0',0
g_power db '关机',0
g_pc_title db '我的电脑',0
g_cp_title db '控制面板',0
g_book_title db '桃花源记',0
g_anykey db '按任意键返回桌面',0
g_show_title db '显示设置',0
g_snd_title db '声音设置',0
g_about_title db '关于NexOS',0
g_reinst_title db '重装系统',0
g_shutdown db '系统已关机, 可以安全关闭电源',13,10,0
g_pc_info db '硬盘: NXFS 已安装',13,10,13,10,'根目录:',13,10,'HELLO.C0W',13,10,'README.TXT',13,10,13,10,'容量: 63MB (IDE)',0
g_cp_menu db '1. 显示',13,10,'2. 声音',13,10,'3. 关于NexOS',13,10,'4. 重装系统',0
g_cp_show db '分辨率: 320x200',13,10,'颜色: 256色',13,10,'4:3 模式',13,10,'(8K 需要显卡支持)',0
g_cp_snd db '音量: 100',13,10,'静音: 关',13,10,'声道: 立体声',13,10,'输出: 扬声器',0
g_cp_about db 'NexOS v1.0',13,10,'使用豆包开发',13,10,'(c) 2026 作者微信 hksxlyb',13,10,'捐赠: C:/NexOS/skm.jpg',0
g_cp_reinst db '重装 NexOS:',13,10,'进入 NexDOS 后',13,10,'输入 INSTALL 回车',0
g_w_close db 'x',0
g_w_max db '[]',0
g_w_min db '-',0
g_book_hint db '空格:下一页 T:翻译 B:上一页 Esc:关闭',0
g_btn_prev db '上一页',0
g_btn_tr db '翻译',0
g_btn_next db '下一页',0
g_btn_close db '关闭',0
g_book_err db '未找到 TAOHUA.TXT',13,10,'请先安装 NexOS 到硬盘!',0
g_bmode db 0
g_bpage db 0
page_buf times 400 db 0
g_ptitle dw 0
g_content dw 0
m_x dw 160
m_y dw 100
m_left db 0
m_prev db 0
mp_st db 0
; ----- 内置 "↖" 光标字形 16x16 (尖端左上, XOR 绘制) -----
cur_shape:
db 0xF0,0x00   ; ####.............  箭头头部
db 0xE8,0x00   ; ###.#............
db 0xC8,0x00   ; ##..#............
db 0x88,0x00   ; #...#............
db 0x84,0x00   ; #....#...........
db 0x82,0x00   ; #.....#..........
db 0x81,0x00   ; #......#.........
db 0x80,0x80   ; #.......#........
db 0x80,0x40   ; #........#.......
db 0x80,0x20   ; #.........#......
db 0x80,0x10   ; #..........#.....
db 0x80,0x08   ; #...........#....
db 0x80,0x04   ; #............#...
db 0x80,0x02   ; #.............#..
db 0x80,0x01   ; #..............#.
db 0x80,0x01   ; #...............#
mp_b0 db 0
mp_xd db 0
mp_yd db 0
cur_visible db 0
old_x dw 0
old_y dw 0

; ----- 16x16 彩色图标: cx=x, dx=y, al=fill -----
draw_icon:
push ax
push bx
push cx
push dx
push di
push es
mov bx,0xA000
mov es,bx
mov ax,dx
mov bx,320
mul bx
add ax,cx
mov di,ax
mov cx,16
.irow:
push cx
mov cx,16
.irowx:
mov [es:di],al
inc di
dec cx
jnz .irowx
add di,304
pop cx
dec cx
jnz .irow
pop es
pop di
pop dx
pop cx
pop bx
pop ax
ret

; ===== 安装程序数据 =====

; ===== OOBE 安装向导字符串 =====
ow_win_title db 'NexOS 安装程序',0
ow_welcome db '欢迎使用 NexOS 安装程序',0
ow_wtext1 db '本程序将把 NexOS 安装到您的硬盘。',0
ow_wtext2 db '安装将格式化硬盘，请备份数据！',0
ow_hint db '按 Enter 继续，按 Esc 退出。',0
btn_next db '下一步 >',0
btn_retry db '重试',0
btn_reboot db '重启',0
ow_hd_title db '硬盘检测',0
ow_detecting db '正在检测硬盘，请稍候...',0
ow_hd_ok db '检测到硬盘：',0
ow_hd_cyl db '参数：',0
ow_comma db ',',0
ow_hd_mb db '容量：',0
ow_mb db ' MB',0
ow_nohd1 db '未检测到硬盘！',0
ow_nohd2 db '请检查硬盘连接后重试。',0
ow_sel_title db '选择安装方式',0
ow_sel_ask db '请选择安装方式：',0
opt1 db '1) 分区并格式化为 NXFS',0
opt2 db '2) 仅格式化（不分区）',0
opt3 db '3) 跳过（保留现有数据）',0
ow_sel_key db '按上下方向键选择，按 Enter 确认',0
ow_sel_mark db '>',0
ow_work_title db '正在安装',0
ow_stage_part db '正在分区...',0
ow_stage_fmt db '正在格式化...',0
ow_copy_title db '正在复制文件',0
ow_copy_text db '正在复制文件到硬盘：',0
ow_copy_warn db '请勿关闭电源或重启电脑...',0
ow_file_hello db '正在复制 HELLO...',0
ow_file_readme db '正在复制 README...',0
ow_file_taohua db '正在复制 TAOHUA...',0
ow_file_wall db '正在复制 WALL.BIN...',0
ow_done_pct db '已完成 ',0
ow_pct db '%',0
ow_done_title db '安装完成',0
ow_done1 db 'NexOS 安装完成！',0
ow_done2 db '正在重新启动...',0
ow_done3 db '正在重新启动...',0
ow_rebooting db '正在重新启动...',0
ow_err_title db '安装失败',0
ow_err1 db '写入硬盘失败！',0
ow_err2 db '请检查硬盘后重新安装。',0
sel_cur db 1
ow_pct_cur dw 0
st_title db 'NexDOS 安装程序 V1.0',13,10,0
st_detect db '正在检测硬盘...',13,10,0
st_hd db '检测到硬盘 ',0
st_cyl db '柱面:',0
st_head db '磁头:',0
st_spt db '每道扇区:',0
st_mb db '容量(MB):',0
st_confirm db '是否分区并格式化为 NXFS?',13,10,'按 Y 继续, 按 N 取消',0
st_part db '正在创建分区...',0
st_fmt db '正在格式化 NXFS...',0
st_copy db '正在复制文件...',0
st_done db '安装完成! 请重启电脑',0
st_nohd db '未检测到硬盘!',0
st_cancel db '已取消安装',0
st_wrfail db '写入硬盘失败! DISK ERROR',0
hdr_c0w db 'This Is A C0W Program'
fn_hello db 'HELLO   C0W'
fn_readme db 'README  TXT'
fn_taohua db 'TAOHUA  TXT'
fn_wall db 'WALL    BIN'
txt_x dw 0
txt_y dw 0
oobe_title_sv dw 0
char_col db 7
hd_num db 0
hd_cyl dd 0
hd_head dd 0
hd_spt dd 0
hd_sectors dd 0
hd_mb dd 0
numbuf times 16 db 0
diskbuf times 512 db 0
dap db 0x10,0
dap_cnt dw 1
dap_off dw 0
dap_seg dw 0x0840
dap_lba dd 0
dd 0

; ===== 内置虚拟文件系统 (每项16字节: 12名字+null + dw offset + dw size) =====
vfs_table:
dw 2
db 'HELLO   C0W',0
dw hello_code
dw hello_size
db 'README  TXT',0
dw readme_code
dw readme_size

; ================= 键盘中断 (int 0x09 IRQ1 + int 0x16) =================
; 数据区
kb_buf times 128 db 0        ; 环形缓冲 (64项 word: AX 值)
kb_head dw 0
kb_tail dw 0
kb_ctrl db 0
kb_shift db 0
kb_ctrlc db 0

; 扫描码表 (make table 1, 0x00-0x57)
scancode_map:
db 0,0x1B,'1','2','3','4','5','6','7','8','9','0','-','=',0x08,0x09
db 'q','w','e','r','t','y','u','i','o','p','[',']',0x0D,0,'a','s'
db 'd','f','g','h','j','k','l',';',0x27,'`',0,0x5C,'z','x','c','v'
db 'b','n','m',',','.','/',0,'*',0,' ',0,0,0,0,0,0
db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
db 0,0,0,0,0,0,0,0

; ===== int 0x09: 键盘硬件中断 =====
kbd_isr:
push ax
push bx
push si
push ds
mov ax,0x0840
mov ds,ax
in al,0x60
mov bl,al
; 键盘控制器确认
in al,0x61
mov ah,al
or al,0x80
out 0x61,al
xchg ah,al
out 0x61,al
; EOI
mov al,0x20
out 0x20,al
; 处理扫描码
test bl,0x80
jnz .kb_rel
mov al,bl
; Ctrl / Shift 按下
cmp al,0x1D
je .kb_ctrl_on
cmp al,0x2A
je .kb_shift_on
cmp al,0x36
je .kb_shift_on
; Ctrl+C: 扫描码 0x2E (C) + Ctrl 按下
cmp al,0x2E
jne .kb_chk
cmp byte [kb_ctrl],1
jne .kb_chk
mov byte [kb_ctrlc],1
jmp .kb_exit
.kb_chk:
; 扩展键 (F1-F10 0x3B-0x44, 方向 0x47-0x53) -> AX=0xXX00
cmp al,0x3B
jb .kb_map
cmp al,0x44
jbe .kb_ext
cmp al,0x47
jb .kb_map
cmp al,0x53
jbe .kb_ext
.kb_map:
cmp al,0x57
ja .kb_exit
mov bx,scancode_map
xor ah,ah
add bx,ax
mov al,[bx]
or al,al
jz .kb_exit
; Shift -> 字母大写
cmp byte [kb_shift],1
jne .kb_shift_ok
cmp al,'a'
jb .kb_shift_ok
cmp al,'z'
ja .kb_shift_ok
sub al,0x20
.kb_shift_ok:
xor ah,ah
jmp .kb_push
.kb_ext:
mov ah,al
xor al,al
.kb_push:
; 入缓冲 (每项 2 字节, 索引按 2 递增, 64 项 -> and 0x7E)
mov si,[kb_head]
mov [kb_buf+si],ax
add si,2
and si,0x7E
mov [kb_head],si
jmp .kb_exit
.kb_ctrl_on:
mov byte [kb_ctrl],1
jmp .kb_exit
.kb_shift_on:
mov byte [kb_shift],1
jmp .kb_exit
.kb_rel:
and al,0x7F
cmp al,0x1D
je .kb_ctrl_off
cmp al,0x2A
je .kb_shift_off
cmp al,0x36
je .kb_shift_off
.kb_exit:
pop ds
pop si
pop bx
pop ax
iret
.kb_ctrl_off:
mov byte [kb_ctrl],0
jmp .kb_exit
.kb_shift_off:
mov byte [kb_shift],0
jmp .kb_exit

; ===== int 0x16: 键盘服务 =====
; AH=0 读键(阻塞) AH=1 检测(ZF=1无键) AH=2 shift状态
int16_isr:
pushf
cli
push bx
push si
push ds
push bp
mov bp,sp
mov ax,0x0840
mov ds,ax
cmp ah,0
je .i16_read
cmp ah,1
je .i16_check
cmp ah,2
je .i16_shift
.i16_ret:
pop bp
pop ds
pop si
pop bx
popf
iret
.i16_shift:
; AH=2: al=shift 状态
mov al,0
cmp byte [kb_ctrl],1
jne .i16_s2
or al,0x04
.i16_s2:
cmp byte [kb_shift],1
jne .i16_s3
or al,0x08
.i16_s3:
jmp .i16_ret
.i16_read:
mov si,[kb_tail]
cmp si,[kb_head]
jne .i16_got
; 空缓冲: 开中断等待
sti
hlt
cli
jmp .i16_read
.i16_got:
mov ax,[kb_buf+si]
add si,2
and si,0x7E
mov [kb_tail],si
jmp .i16_ret
.i16_check:
mov si,[kb_tail]
cmp si,[kb_head]
jne .i16_ck1
; 无键: 返回帧 FLAGS ZF=1 (bp+14: bp ds si bx pushf | IP CS FLAGS)
or word [bp+14],0x40
jmp .i16_ret
.i16_ck1:
and word [bp+14],0xFFBF
jmp .i16_ret

; ===== kb_setup: 安装中断向量 =====
kb_setup:
push ax
push bx
push es
cli
mov ax,0
mov es,ax
mov di,0x09*4
mov word [es:di],kbd_isr
mov word [es:di+2],0x0840
mov di,0x16*4
mov word [es:di],int16_isr
mov word [es:di+2],0x0840
; 清缓冲
mov word [kb_head],0
mov word [kb_tail],0
mov byte [kb_ctrl],0
mov byte [kb_shift],0
mov byte [kb_ctrlc],0
sti
pop es
pop bx
pop ax
ret

; ===== check_ctrlc: 有 Ctrl+C 则清标志 CF=1 =====
check_ctrlc:
push ax
push ds
mov ax,0x0840
mov ds,ax
cli
mov al,[kb_ctrlc]
mov byte [kb_ctrlc],0
sti
or al,al
jnz .cc_y
pop ds
pop ax
clc
ret
.cc_y:
pop ds
pop ax
stc
ret
