org 0x7C00
bits 16
; ... 读 LBA 1..8 到 0x0840:0，跳转
times 510-($-$$) db 0
dw 0xAA55