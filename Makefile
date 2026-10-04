CC      = gcc
CFLAGS  = -m32 -std=gnu99 -ffreestanding -O2 -Wall -Wextra -fno-pie
LDFLAGS = -m32 -T linker.ld -ffreestanding -O2 -nostdlib -no-pie

USER_CFLAGS  = -m32 -std=gnu99 -ffreestanding -O2 -Wall -Wextra \
               -fno-pie -fno-stack-protector -fno-builtin
USER_LDFLAGS = -m32 -T user/user.ld -ffreestanding -O2 -nostdlib -no-pie

OBJS = build/boot.o build/kmain.o \
       build/gdt.o build/gdt_flush.o \
       build/idt.o build/idt_flush.o \
       build/isr.o build/isr_stub.o \
       build/pmm.o build/paging.o build/paging_flush.o \
       build/heap.o \
       build/thread.o build/sched.o build/switch.o \
       build/timer.o build/ipc.o \
       build/syscall.o build/usermode.o \
       build/elf_loader.o build/init_elf.o

all: build/NexOS-NEXT.iso

build:
	mkdir -p build

build/%.o: boot/%.S | build
	$(CC) $(CFLAGS) -c $< -o $@

build/%.o: kernel/%.c | build
	$(CC) $(CFLAGS) -c $< -o $@

build/%.o: kernel/%.S | build
	$(CC) $(CFLAGS) -c $< -o $@

# 用户程序
build/user_start.o: user/start.S | build
	$(CC) $(USER_CFLAGS) -c $< -o $@

build/user_main.o: user/main.c | build
	$(CC) $(USER_CFLAGS) -c $< -o $@

build/init.elf: build/user_start.o build/user_main.o user/user.ld
	$(CC) $(USER_LDFLAGS) -o $@ build/user_start.o build/user_main.o

# init_elf.o 依赖 build/init.elf
build/init_elf.o: kernel/init_elf.S build/init.elf | build
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

clean:
	rm -rf build