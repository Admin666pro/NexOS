#!/bin/bash
set -e

git add .
git add --renormalize .

# 1. 编译
make clean
make

# 2. 组装镜像
IMG=NexOS.img
dd if=/dev/zero of=$IMG bs=512 count=32768 status=none
dd if=build/mbr.bin    of=$IMG bs=512 conv=notrunc status=none
dd if=build/hdboot.bin of=$IMG bs=512 seek=1 conv=notrunc status=none
dd if=build/kernel.bin of=$IMG bs=512 seek=2 conv=notrunc status=none

echo "==> $IMG 已生成"

# 3. 可选：生成 ISO
if [ "$1" = "iso" ]; then
    sudo apt install -y grub-pc-bin xorriso mtools syslinux-common
    rm -rf iso
    mkdir -p iso/boot/grub
    cp $IMG iso/boot/NexOS.img
    cp /usr/lib/syslinux/memdisk iso/boot/ 2>/dev/null || \
        cp /usr/share/syslinux/memdisk iso/boot/
    printf 'set timeout=0\nset default=0\n\nmenuentry "NexOS" {\n  linux16 /boot/memdisk\n  initrd16 /boot/NexOS.img\n}\n' > iso/boot/grub/grub.cfg
    grub-mkrescue -o NexOS.iso iso
    echo "==> NexOS.iso 已生成"
fi