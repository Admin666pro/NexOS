#include <stdint.h>
#include "gdt.h"
#include "idt.h"
#include "pmm.h"
#include "paging.h"
#include "heap.h"
#include "thread.h"
#include "timer.h"
#include "sched.h"
#include "serial.h"
#include "syscall.h"
#include "elf_loader.h"
#include "elf.h"
#include "kbd.h"
#include "io.h"
#include "vfs.h"
#include "ata.h"
#include "nxfs.h"

#define VGA_MEMORY ((volatile uint16_t *)0xB8000)
#define VGA_WIDTH  80
#define VGA_HEIGHT 25

static int cursor = 0;

static void vga_move_cursor(void) {
    uint16_t pos = cursor;
    outb(0x3D4, 0x0F);
    outb(0x3D5, (uint8_t)(pos & 0xFF));
    outb(0x3D4, 0x0E);
    outb(0x3D5, (uint8_t)((pos >> 8) & 0xFF));
}

static void vga_scroll(void) {
    for (int i = 0; i < (VGA_HEIGHT - 1) * VGA_WIDTH; i++)
        VGA_MEMORY[i] = VGA_MEMORY[i + VGA_WIDTH];
    for (int i = (VGA_HEIGHT - 1) * VGA_WIDTH;
         i < VGA_HEIGHT * VGA_WIDTH; i++)
        VGA_MEMORY[i] = (uint16_t)((0x07 << 8) | ' ');
    cursor = (VGA_HEIGHT - 1) * VGA_WIDTH;
}

void vga_clear(void) {
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++)
        VGA_MEMORY[i] = (uint16_t)((0x07 << 8) | ' ');
    cursor = 0;
    outb(0x3D4, 0x0A); outb(0x3D5, 0x0E);
    outb(0x3D4, 0x0B); outb(0x3D5, 0x0F);
    vga_move_cursor();
}

void vga_putc(char c) {
    serial_putc(c);
    if (c == '\r') {
        cursor = (cursor / VGA_WIDTH) * VGA_WIDTH;
        vga_move_cursor();
        return;
    }
    if (c == '\n') {
        cursor = (cursor / VGA_WIDTH + 1) * VGA_WIDTH;
    } else if (c == '\b') {
        if (cursor > 0) {
            cursor--;
            VGA_MEMORY[cursor] = (uint16_t)((0x07 << 8) | ' ');
        }
        vga_move_cursor();
        return;
    } else {
        VGA_MEMORY[cursor++] = (uint16_t)((0x07 << 8) | (uint8_t)c);
    }
    if (cursor >= VGA_WIDTH * VGA_HEIGHT) vga_scroll();
    vga_move_cursor();
}

void vga_puts(const char *s) { while (*s) vga_putc(*s++); }

void vga_hex(uint32_t v) {
    const char *h = "0123456789ABCDEF";
    vga_puts("0x");
    for (int i = 28; i >= 0; i -= 4) vga_putc(h[(v >> i) & 0xF]);
}

extern const uint8_t init_elf_start[];
extern const uint8_t init_elf_end[];

void kmain(void) {
    serial_init();
    vga_clear();
    vga_puts("=== FRESH BOOT ===\n");
    gdt_init();
    idt_init();
    syscall_init();

    vga_puts("NexOS-NEXT 32-bit microkernel\n");
    vga_puts("=============================\n");

    pmm_init();      vga_puts("[OK] PMM\n");
    paging_init();      vga_puts("[OK] Paging\n");
    heap_init();        vga_puts("[OK] Heap\n");
    vfs_init();         vga_puts("[OK] VFS (ramfs)\n");
    thread_init();
    timer_init();       vga_puts("[OK] Timer @100Hz\n");
    vga_puts("BEFORE kbd_init\n");                          
    kbd_init();
    vga_puts("AFTER kbd_init\n");
    //kbd_init();         vga_puts("[OK] Keyboard\n");

    vga_puts("[OK] Syscalls (int 0x80)\n");
    vga_puts("[OK] User mode (ring 3)\n");
    vga_puts("[OK] IPC\n\n");

    /* ★ 开中断，让后面的 kbd_confirm 能工作 */
    /* __asm__ volatile("sti"); */   /* ← 注释掉这一行 */

    /* ATA 初始化 */
    if (ata_init() < 0) {
        vga_puts("[FAIL] ATA init\n");
        for (;;) __asm__ volatile("hlt");
    }
    vga_puts("[OK] ATA (primary master)\n");

    /* ★ 挂载 NXFS，可能会问用户 */
    int nx = nxfs_init();
    if (nx < 0) {
        vga_puts("[FAIL] NXFS mount, code=");
        vga_hex((uint32_t)nx);
        vga_puts("\n");
        for (;;) __asm__ volatile("hlt");
    }
    vga_puts("[OK] NXFS mounted\n");
    vfs_use_nxfs();
    vga_puts("[OK] VFS now on NXFS\n\n");

    /* 加载 init ELF */
    uint32_t elf_size = (uint32_t)(init_elf_end - init_elf_start);
    vga_puts("Loading init ELF (size=");
    vga_hex(elf_size);
    vga_puts(")...\n");

    elf_load_result_t elf;
    int r = elf_load(init_elf_start, elf_size, &elf);
    if (r) {
        vga_puts("[FAIL] elf_load = ");
        vga_hex((uint32_t)r);
        vga_puts("\n");
        for (;;) __asm__ volatile("hlt");
    }

    vga_puts("[OK] ELF loaded, entry=");
    vga_hex(elf.entry);
    vga_puts(" stack=");
    vga_hex(elf.stack_top);
    vga_puts("\n\n");

    thread_create_elf(elf.entry, elf.stack_top);

    for (volatile int i = 0; i < 30000000; i++);
    sched_start();
}