#include <stdint.h>
#include "gdt.h"
#include "idt.h"
#include "pmm.h"
#include "paging.h"
#include "heap.h"
#include "thread.h"
#include "timer.h"
#include "sched.h"
#include "ipc.h"
#include "syscall.h"
#include "io.h"

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
    vga_move_cursor();
}

void vga_putc(char c) {
    if (c == '\r') {
        cursor = (cursor / VGA_WIDTH) * VGA_WIDTH;
        vga_move_cursor();
        return;
    }
    if (c == '\n') {
        cursor = (cursor / VGA_WIDTH + 1) * VGA_WIDTH;
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

void vga_dec(uint32_t v) {
    char buf[16]; int i = 0;
    if (v == 0) { vga_putc('0'); return; }
    while (v > 0) { buf[i++] = '0' + (v % 10); v /= 10; }
    while (i--) vga_putc(buf[i]);
}

extern int  g_receiver_tid;
extern void user_receiver(void);
extern void user_sender(void);

void kmain(uint32_t magic, uint32_t mbi) {
    vga_clear();

    gdt_init();
    idt_init();
    syscall_init();

    vga_puts("NexOS-NEXT 32-bit microkernel\n");
    vga_puts("\n");

    if (magic != 0x2BADB002) {
        vga_puts("[FAIL] bad multiboot magic\n");
        for (;;) __asm__ volatile("hlt");
    }

    pmm_init(mbi);      vga_puts("[OK] PMM\n");
    paging_init();      vga_puts("[OK] Paging\n");
    heap_init();        vga_puts("[OK] Heap\n");
    thread_init();
    timer_init();       vga_puts("[OK] Timer @100Hz\n");
    vga_puts("[OK] Syscalls (int 0x80)\n");
    vga_puts("[OK] User mode (ring 3)\n");
    vga_puts("[OK] IPC\n\n");

    vga_puts("Booting user threads...\n\n");

    thread_t *r = thread_create_user(user_receiver);
    if (!r) { vga_puts("[FAIL] receiver create\n"); for (;;) __asm__ volatile("hlt"); }
    g_receiver_tid = r->id;

    thread_t *s = thread_create_user(user_sender);
    if (!s) { vga_puts("[FAIL] sender create\n"); for (;;) __asm__ volatile("hlt"); }

    for (volatile int i = 0; i < 30000000; i++);
    sched_start();
}