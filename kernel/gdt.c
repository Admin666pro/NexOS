// gdt.c
#include "gdt.h"
#include <stdint.h>

struct gdt_entry {
    uint16_t limit_low;
    uint16_t base_low;
    uint8_t  base_mid;
    uint8_t  access;
    uint8_t  granularity;
    uint8_t  base_high;
} __attribute__((packed));

struct tss_entry {
    uint32_t prev_tss;
    uint32_t esp0, ss0;
    uint32_t esp1, ss1;
    uint32_t esp2, ss2;
    uint32_t cr3, eip, eflags;
    uint32_t eax, ecx, edx, ebx, esp, ebp, esi, edi;
    uint32_t es, cs, ss, ds, fs, gs;
    uint32_t ldt;
    uint16_t trap;
    uint16_t iomap_base;
} __attribute__((packed));

struct gdt_ptr {
    uint16_t limit;
    uint32_t base;
} __attribute__((packed));

static struct gdt_entry gdt[6];
static struct gdt_ptr   gp;
static struct tss_entry tss;

extern void gdt_flush(uint32_t);
extern void tss_flush(void);

static void gdt_set(int i, uint32_t base, uint32_t limit,
                    uint8_t access, uint8_t gran) {
    gdt[i].base_low    = base & 0xFFFF;
    gdt[i].base_mid    = (base >> 16) & 0xFF;
    gdt[i].base_high   = (base >> 24) & 0xFF;
    gdt[i].limit_low   = limit & 0xFFFF;
    gdt[i].granularity = ((limit >> 16) & 0x0F) | (gran & 0xF0);
    gdt[i].access      = access;
}

void gdt_init(void) {
    gp.limit = sizeof(gdt) - 1;
    gp.base  = (uint32_t)&gdt;

    gdt_set(0, 0, 0,          0x00, 0x00);
    gdt_set(1, 0, 0xFFFFF,    0x9A, 0xCF);   // 0x08 内核代码
    gdt_set(2, 0, 0xFFFFF,    0x92, 0xCF);   // 0x10 内核数据
    gdt_set(3, 0, 0xFFFFF,    0xFA, 0xCF);   // 0x18 用户代码
    gdt_set(4, 0, 0xFFFFF,    0xF2, 0xCF);   // 0x20 用户数据

    /* TSS */
    uint32_t base  = (uint32_t)&tss;
    uint32_t limit = sizeof(tss) - 1;
    gdt_set(5, base, limit, 0x89, 0x00);     // 0x28 TSS

    /* 清零 TSS */
    uint8_t *p = (uint8_t *)&tss;
    for (uint32_t i = 0; i < sizeof(tss); i++) p[i] = 0;
    tss.ss0  = 0x10;
    tss.iomap_base = sizeof(tss);

    gdt_flush((uint32_t)&gp);
    tss_flush();
}

void gdt_set_kernel_stack(uint32_t esp0) {
    tss.esp0 = esp0;
}