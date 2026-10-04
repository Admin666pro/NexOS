; NexDOS 内核主文件
; 编译: nasm -f bin -o kernel.bin kernel/kernel.asm

org 0x0000
bits 16

%include "start.asm"
%include "kmain.asm"
%include "data.asm"

%include "../drivers/disk.asm"
%include "../drivers/kbd.asm"
%include "../drivers/mouse.asm"
%include "../drivers/vga.asm"

%include "../gfx/font_ascii.asm"
%include "../gfx/font_han.asm"
%include "../gfx/text.asm"

%include "../fs/nxfs.asm"
%include "../fs/vfs.asm"

%include "pmode.asm"
%include "shell.asm"

%include "../gui/desktop.asm"
%include "../gui/window.asm"
%include "../gui/start_menu.asm"
%include "../gui/mycomp.asm"
%include "../gui/book.asm"

%include "../install/oobe.asm"
%include "../install/partition.asm"
%include "../install/install_data.asm"

%include "../apps/hello.asm"
%include "../apps/readme.asm"