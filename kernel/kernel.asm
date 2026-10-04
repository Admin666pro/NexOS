; NexDOS 内核主文件
bits 16

%include "start.asm"
%include "kmain.asm"
%include "data.asm"
%include "pmode.asm"
%include "shell.asm"

%include "disk.asm"
%include "kbd.asm"
%include "mouse.asm"
%include "vga.asm"

%include "font_ascii.asm"
%include "font_han.asm"
%include "text.asm"

%include "nxfs.asm"
%include "vfs.asm"

%include "desktop.asm"
%include "window.asm"
%include "start_menu.asm"
%include "mycomp.asm"
%include "book.asm"

%include "oobe.asm"
%include "partition.asm"
%include "install_data.asm"

%include "c_api.asm"