CC      = gcc
CFLAGS  = -m32 -std=gnu99 -ffreestanding -O2 -Wall -Wextra -fno-pie
LDFLAGS = -m32 -T linker.ld -ffreestanding -O2 -nostdlib -no-pie

OBJS = build/boot.o build/kmain.o \
       build/gdt.o build/gdt_flush.o \
       build/idt.o build/idt_flush.o \
       build/isr.o build/isr_stub.o \
       build/pmm.o build/paging.o build/paging_flush.o \
       build/heap.o \
       build/thread.o build/sched.o build/switch.o \
       build/timer.o build/ipc.o

all: build/NexOS-NEXT.iso

build:
	mkdir -p build

build/%.o: boot/%.S | build
	$(CC) $(CFLAGS) -c $< -o $@

build/%.o: kernel/%.c | build
	$(CC) $(CFLAGS) -c $< -o $@

build/%.o: kernel/%.S | build
	$(CC) $(CFLAGS) -c $< -o $@

build/NexOS-NEXT.elf: $(OBJS) linker.ld
	$(CC) $(LDFLAGS) -o $@ $(OBJS) -lgcc

build/NexOS-NEXT.iso: build/NexOS-NEXT.elf grub.cfg
	mkdir -p build/iso/boot/grub
	cp build/NexOS-NEXT.elf build/iso/boot/
	cp grub.cfg build/iso/boot/grub/
	grub-mkrescue -o $@ build/iso

run: build/NexOS-NEXT.iso
	qemu-system-i386 -cdrom build/NexOS-NEXT.iso -boot d

debug: build/NexOS-NEXT.iso
	qemu-system-i386 -cdrom build/NexOS-NEXT.iso -boot d -d int,cpu_reset -D qemu.log

clean:
	rm -rf build