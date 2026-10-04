#include <stdint.h>
#include "gdt.h"
#include "idt.h"
#include "pmm.h"
#include "heap.h"
#include "paging.h"
#include "thread.h"
#include "timer.h"
#include "sched.h"
#include "thread.h"
#include "timer.h"
#include "sched.h"
#include "ipc.h"

#define VGA_MEMORY ((volatile uint16_t *)0xB8000)
#define VGA_WIDTH  80
#define VGA_HEIGHT 25

static int cursor = 0;

void vga_clear(void) {
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++)
        VGA_MEMORY[i] = (uint16_t)((0x07 << 8) | ' ');
    cursor = 0;
}
void vga_putc(char c) {
    if (c == '\n') { cursor = (cursor / VGA_WIDTH + 1) * VGA_WIDTH; return; }
    if (c == '\r') { cursor = (cursor / VGA_WIDTH) * VGA_WIDTH; return; }
    VGA_MEMORY[cursor++] = (uint16_t)((0x07 << 8) | (uint8_t)c);
    if (cursor >= VGA_WIDTH * VGA_HEIGHT) cursor = 0;
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

static int receiver_id = -1;

static void thread_receiver(void) {
    vga_puts("[R] receiver started\n");
    for (int i = 0; i < 5; i++) {
        message_t m;
        ipc_recv(&m);
        vga_puts("[R] got: ");
        vga_puts((const char *)m.data);
        vga_puts("  from thread ");
        vga_dec(m.sender);
        vga_putc('\n');
    }
    vga_puts("[R] done, exiting loop\n");
    for (;;) __asm__ volatile("hlt");
}

static void thread_sender(void) {
    for (volatile int i = 0; i < 5000000; i++);

    for (int i = 0; i < 5; i++) {
        message_t m = {0};
        m.sender = current_thread->id;
        m.type   = 1;

        char *p = (char *)m.data;
        p[0]='m'; p[1]='s'; p[2]='g'; p[3]='-';
        p[4]='0'+i; p[5]=0;

        vga_puts("[S] sending msg-");
        vga_putc('0'+i);
        vga_putc('\n');

        ipc_send(receiver_id, &m);

        for (volatile int j = 0; j < 10000000; j++);
    }
    vga_puts("[S] done\n");
    for (;;) __asm__ volatile("hlt");
}

static void thread_A(void) {
    for (;;) {
        vga_puts("A");
        for (volatile int i = 0; i < 500000; i++);
    }
}

static void thread_B(void) {
    for (;;) {
        vga_puts("B");
        for (volatile int i = 0; i < 500000; i++);
    }
}

void kmain(uint32_t magic, uint32_t mbi) {
    vga_clear();
    gdt_init();
    idt_init();

    vga_puts("NexOS-NEXT 32-bit kernel booted!\n");
    if (magic != 0x2BADB002) {
        vga_puts("[FAIL] bad multiboot magic\n");
        for (;;) __asm__ volatile("hlt");
    }

    pmm_init(mbi);
    vga_puts("[OK] PMM\n");
    paging_init();
    vga_puts("[OK] Paging\n");
    heap_init();
    vga_puts("[OK] Heap\n");

    thread_init();
    timer_init();
    vga_puts("[OK] Timer @100Hz, scheduler ready\n\n");

    vga_puts("IPC test: receiver + sender\n\n");

    thread_t *r = thread_create(thread_receiver);
    receiver_id = r->id;

    thread_create(thread_sender);

    for (volatile int i = 0; i < 30000000; i++);

    sched_start();
}