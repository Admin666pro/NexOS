#include "idt.h"
#include "io.h"
#include <stdint.h>

struct idt_entry {
    uint16_t base_low;
    uint16_t sel;
    uint8_t  always0;
    uint8_t  flags;
    uint16_t base_high;
} __attribute__((packed));

struct idt_ptr {
    uint16_t limit;
    uint32_t base;
} __attribute__((packed));

static struct idt_entry idt[256];
static struct idt_ptr   ip;

extern void idt_flush(uint32_t);
extern uint32_t isr_stub_table[];

static void idt_set(int n, uint32_t base, uint16_t sel, uint8_t flags) {
    idt[n].base_low  = base & 0xFFFF;
    idt[n].base_high = (base >> 16) & 0xFFFF;
    idt[n].sel       = sel;
    idt[n].always0   = 0;
    idt[n].flags     = flags;
}

static void pic_remap(void) {
    outb(0x20, 0x11); io_wait();
    outb(0xA0, 0x11); io_wait();
    outb(0x21, 0x20); io_wait();   // 主 PIC -> 0x20
    outb(0xA1, 0x28); io_wait();   // 从 PIC -> 0x28
    outb(0x21, 0x04); io_wait();
    outb(0xA1, 0x02); io_wait();
    outb(0x21, 0x01); io_wait();
    outb(0xA1, 0x01); io_wait();
    outb(0x21, 0x00);
    outb(0xA1, 0x00);
}

void idt_init(void) {
    ip.limit = sizeof(idt) - 1;
    ip.base  = (uint32_t)&idt;

    for (int i = 0; i < 256; i++)
        idt_set(i, 0, 0, 0);

    for (int i = 0; i < 48; i++)
        idt_set(i, isr_stub_table[i], 0x08, 0x8E);

    pic_remap();
    idt_flush((uint32_t)&ip);
}