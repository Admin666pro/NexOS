; 全局数据

txt_x        dw 0
txt_y        dw 0
char_col     db 7
oobe_title_sv dw 0

boot_drv     db 0
saved_sp     dw 0

hd_num       db 0
hd_cyl       dd 0
hd_head      dd 0
hd_spt       dd 0
hd_sectors   dd 0
hd_mb        dd 0

numbuf       times 16  db 0
diskbuf      times 512 db 0

dap          db 0x10,0
dap_cnt      dw 1
dap_off      dw 0
dap_seg      dw 0x0840
dap_lba      dd 0
             dd 0

cmdline      times 64  db 0
searchname   times 11  db 0

idtr_real:
    dw 0x3FF
    dd 0