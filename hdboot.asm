org 0x7C00
bits 16
start:
mov [boot_drv],dl
mov ax,0x0840
mov es,ax
xor bx,bx
mov word [lba],1
mov word [cnt],8
read_loop:
mov word [dap_off],bx
mov word [dap_seg],0x0840
mov word [dap_cnt],1
mov ax,[lba]
mov word [dap_lba],ax
mov word [dap_lba+2],0
mov dl,[boot_drv]
mov ah,0x42
mov si,dap
int 0x13
jc boot_err
add bx,512
inc word [lba]
dec word [cnt]
jnz read_loop
mov dl,[boot_drv]
jmp 0x0840:0x0000
boot_err:
mov si,err_msg
mov ah,0x0E
.el:
lodsb
or al,al
jz .h
int 0x10
jmp .el
.h:
hlt
jmp .h
err_msg db 'NexDOS HDD boot failed',0
boot_drv db 0
lba dw 0
cnt dw 0
dap db 0x10,0
dap_cnt dw 1
dap_off dw 0
dap_seg dw 0x0840
dap_lba dd 0
dd 0
times 510-($-$$) db 0
dw 0xAA55
