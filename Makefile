CC      = gcc
CFLAGS  = -m32 -std=gnu99 -ffreestanding -O2 -Wall -Wextra -fno-pie
LDFLAGS = -m32 -T linker.ld -ffreestanding -O2 -nostdlib -no-pie

OBJS = build/boot.o build/kmain.o build/gdt.o build/gdt_flush.o \
       build/idt.o build/idt_flush.o build/isr.o build/isr_stub.o

all: build/NexOS.iso

build:
	mkdir -p build

build/%.o: boot/%.S | build
	$(CC) $(CFLAGS) -c $< -o $@

build/%.o: kernel/%.c | build
	$(CC) $(CFLAGS) -c $< -o $@

build/%.o: kernel/%.S | build
	$(CC) $(CFLAGS) -c $< -o $@

build/NexOS.elf: $(OBJS) linker.ld
	$(CC) $(LDFLAGS) -o $@ $(OBJS) -lgcc

build/NexOS.iso: build/NexOS.elf grub.cfg
	mkdir -p build/iso/boot/grub
	cp build/NexOS.elf build/iso/boot/
	cp grub.cfg build/iso/boot/grub/
	grub-mkrescue -o $@ build/iso

run: build/NexOS.iso
	qemu-system-i386 -cdrom build/NexOS.iso -boot d

debug: build/NexOS.iso
	qemu-system-i386 -cdrom build/NexOS.iso -boot d -d int,cpu_reset -D qemu.log

clean:
	rm -rf build