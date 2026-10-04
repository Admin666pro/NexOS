# NexOS Makefile - 纯汇编引导，软盘镜像
ASM = nasm
LD = ld
OBJCOPY = objcopy

BUILD_DIR = build
IMAGE = $(BUILD_DIR)/NexOS.img

# 内核源文件
KERNEL_SOURCES = \
    kernel/boot.asm \
    kernel/kernel.asm \
    kernel/idt.asm \
    drivers/vga.asm \
    drivers/keyboard.asm \
    drivers/mouse.asm \
    ui/desktop.asm

KERNEL_OBJECTS = $(patsubst %.asm,$(BUILD_DIR)/%.o,$(KERNEL_SOURCES))

.PHONY: all clean run

all: $(IMAGE)

# 编译引导扇区
$(BUILD_DIR)/boot.bin: boot/boot.asm
	@mkdir -p $(dir $@)
	$(ASM) -f bin -o $@ $<

# 编译第二阶段
$(BUILD_DIR)/stage2.bin: boot/stage2.asm
	@mkdir -p $(dir $@)
	$(ASM) -f bin -o $@ $<

# 编译内核目标文件
$(BUILD_DIR)/%.o: %.asm
	@mkdir -p $(dir $@)
	$(ASM) -f elf32 -g -o $@ $<

# 链接内核
$(BUILD_DIR)/nexos_kernel.elf: $(KERNEL_OBJECTS)
	$(LD) -m elf_i386 -T linker.ld -o $@ $(KERNEL_OBJECTS)

# 内核转二进制
$(BUILD_DIR)/kernel.bin: $(BUILD_DIR)/nexos_kernel.elf
	$(OBJCOPY) -O binary $< $@

# 生成软盘镜像 (1.44MB)
# 布局: 扇区0=boot, 扇区1-16=stage2 (8KB), 扇区17+=kernel
$(IMAGE): $(BUILD_DIR)/boot.bin $(BUILD_DIR)/stage2.bin $(BUILD_DIR)/kernel.bin
	@mkdir -p $(BUILD_DIR)
	# 创建1.44MB空镜像
	dd if=/dev/zero of=$@ bs=512 count=2880 2>/dev/null
	# 写入boot扇区
	dd if=$(BUILD_DIR)/boot.bin of=$@ bs=512 count=1 conv=notrunc 2>/dev/null
	# 写入stage2 (扇区1开始)
	dd if=$(BUILD_DIR)/stage2.bin of=$@ bs=512 seek=1 conv=notrunc 2>/dev/null
	# 写入kernel (扇区17开始)
	dd if=$(BUILD_DIR)/kernel.bin of=$@ bs=512 seek=17 conv=notrunc 2>/dev/null
	@echo "=== 镜像生成完成 ==="
	@ls -lh $@
	@echo "kernel size: $$(wc -c < $(BUILD_DIR)/kernel.bin) bytes"

run: $(IMAGE)
	qemu-system-i386 -fda $(IMAGE) -m 256 -vga std -display none -monitor unix:/tmp/qemu_mon.sock,server,nowait -serial file:$(BUILD_DIR)/serial.log &
	@echo "QEMU started. Log: $(BUILD_DIR)/serial.log"

clean:
	rm -rf $(BUILD_DIR)/*
