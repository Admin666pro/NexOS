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

int g_receiver_tid = -1;

static void user_receiver(void) {
    __asm__ volatile("int $0x80" :: "a"(1), "b"("[R] user receiver started\n") : "memory");

    for (int i = 0; i < 5; i++) {
        user_msg_t m = {0};

        /* SYS_RECV(&m) —— 没消息时阻塞 */
        __asm__ volatile("int $0x80" :: "a"(4), "b"(&m) : "memory");

        __asm__ volatile("int $0x80" :: "a"(1), "b"("[R] got: ") : "memory");
        __asm__ volatile("int $0x80" :: "a"(1), "b"((const char *)m.data) : "memory");
        __asm__ volatile("int $0x80" :: "a"(1), "b"("  from ") : "memory");

        char tmp[4] = {0};
        tmp[0] = '0' + (m.sender % 10);
        tmp[1] = '\n';
        __asm__ volatile("int $0x80" :: "a"(1), "b"(tmp) : "memory");
    }

    __asm__ volatile("int $0x80" :: "a"(2) : "memory");
    for (;;) __asm__ volatile("pause");
}

static void user_sender(void) {
    /* 等 receiver 就绪 */
    for (volatile int i = 0; i < 20000000; i++);

    for (int i = 0; i < 5; i++) {
        user_msg_t m = {0};
        m.type = 1;
        char *p = (char *)m.data;
        p[0]='m'; p[1]='s'; p[2]='g'; p[3]='-';
        p[4]='0'+i; p[5]=0;

        __asm__ volatile("int $0x80" :: "a"(1), "b"("[S] sending msg\n") : "memory");

        int tid = g_receiver_tid;
        __asm__ volatile("int $0x80" :: "a"(3), "b"(tid), "c"(&m) : "memory");

        for (volatile int j = 0; j < 5000000; j++);
    }

    __asm__ volatile("int $0x80" :: "a"(2) : "memory");
    for (;;) __asm__ volatile("pause");
}

void kmain(uint32_t magic, uint32_t mbi) {
    vga_clear();

    gdt_init();
    idt_init();
    syscall_init();

    vga_puts("NexOS-NEXT 32-bit kernel booted!\n");

    if (magic != 0x2BADB002) {
        vga_puts("[FAIL] bad multiboot magic\n");
        for (;;) __asm__ volatile("hlt");
    }

    pmm_init(mbi);      vga_puts("[OK] PMM\n");
    paging_init();      vga_puts("[OK] Paging\n");
    heap_init();        vga_puts("[OK] Heap\n");
    thread_init();
    timer_init();       vga_puts("[OK] Timer @100Hz\n\n");

    vga_puts("Creating user threads (IPC test)...\n");

    thread_t *r = thread_create_user(user_receiver);
    if (!r) {
        vga_puts("[FAIL] receiver create\n");
        for (;;) __asm__ volatile("hlt");
    }
    g_receiver_tid = r->id;

    thread_t *s = thread_create_user(user_sender);
    if (!s) {
        vga_puts("[FAIL] sender create\n");
        for (;;) __asm__ volatile("hlt");
    }

    for (volatile int i = 0; i < 30000000; i++);
    sched_start();
}