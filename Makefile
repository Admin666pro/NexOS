NASM      = nasm
NASMFLAGS = -f bin -I .

BUILD = build

KERNEL_SRC = kernel/kernel.asm

all: $(BUILD)/mbr.bin $(BUILD)/hdboot.bin $(BUILD)/kernel.bin

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/mbr.bin: boot/mbr.asm | $(BUILD)
	$(NASM) $(NASMFLAGS) -o $@ $<

$(BUILD)/hdboot.bin: boot/hdboot.asm | $(BUILD)
	$(NASM) $(NASMFLAGS) -o $@ $<

# 把 hdboot.bin / wall.bin / taohua.bin 复制到编译目录
$(BUILD)/hdboot.bin: boot/hdboot.asm | $(BUILD)
	$(NASM) $(NASMFLAGS) -o $@ $<

# 内核依赖所有源文件
KERNEL_DEPS = \
	kernel/kernel.asm kernel/start.asm kernel/kmain.asm \
	kernel/shell.asm kernel/pmode.asm kernel/data.asm \
	drivers/disk.asm drivers/kbd.asm drivers/mouse.asm drivers/vga.asm \
	gfx/font_ascii.asm gfx/font_han.asm gfx/text.asm \
	fs/nxfs.asm fs/vfs.asm \
	gui/desktop.asm gui/window.asm gui/start_menu.asm \
	gui/mycomp.asm gui/book.asm \
	install/oobe.asm install/partition.asm install/install_data.asm \
	apps/hello.asm apps/readme.asm

$(BUILD)/kernel.bin: $(KERNEL_DEPS) | $(BUILD)
	cd $(BUILD) && $(NASM) $(NASMFLAGS) -I .. -o kernel.bin ../$(KERNEL_SRC)

clean:
	rm -rf $(BUILD)