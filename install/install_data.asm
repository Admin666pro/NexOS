; 内置二进制数据

segment hdboot_DATA class=FAR_DATA public use16
hdboot_bin:
    incbin 'hdboot.bin'

segment taohua_DATA class=FAR_DATA public use16
taohua_data:
    incbin 'TAOHUA.TXT'