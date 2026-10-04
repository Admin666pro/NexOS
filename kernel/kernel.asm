bits 16

segment data_DATA class=DATA public use16
%include "data.asm"

segment start_TEXT class=CODE public use16
%include "start.asm"
%include "kmain.asm"

segment shell_TEXT class=CODE public use16
%include "shell.asm"
%include "vfs.asm"
%include "nxfs.asm"
%include "disk.asm"

segment gui_TEXT class=CODE public use16
%include "desktop.asm"
%include "window.asm"
%include "start_menu.asm"
%include "mycomp.asm"
%include "book.asm"
%include "oobe.asm"

segment text_TEXT class=CODE public use16
%include "font_ascii.asm"
%include "font_han.asm"
%include "text.asm"

segment drv_TEXT class=CODE public use16
%include "kbd.asm"
%include "mouse.asm"
%include "vga.asm"
%include "pmode.asm"

; ---- C 接口 ----
segment c_api_TEXT class=CODE public use16
%include "c_api.asm"

; ---- 分区 ----
segment partition_TEXT class=CODE public use16
%include "partition.asm"

; ---- 安装数据（大数组，用远段存放）----
segment install_DATA class=FAR_DATA public use16
%include "install_data.asm"