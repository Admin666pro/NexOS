#include <stdint.h>
#include "gdt.h"
#include "idt.h"
#include "pmm.h"
#include "paging.h"

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

void kmain(uint32_t magic, uint32_t mbi) {
    vga_clear();

    gdt_init();
    idt_init();

    vga_puts("NexOS-NEXT 32-bit kernel booted!\n");
    vga_puts("[OK] GDT loaded\n");
    vga_puts("[OK] IDT loaded, PIC remapped\n");

    if (magic != 0x2BADB002) {
        vga_puts("[FAIL] bad multiboot magic\n");
        for (;;) __asm__ volatile("hlt");
    }

    pmm_init(mbi);
    vga_puts("[OK] PMM initialized\n");

    uint32_t total = pmm_total_pages();
    uint32_t used  = pmm_used_pages();
    vga_puts("     Total: "); vga_dec(total); vga_puts(" pages (");
    vga_dec(total * 4 / 1024); vga_puts(" MB)\n");

    paging_init();
    vga_puts("[OK] Paging enabled\n");

    /* 验证分页真的生效了：写一个地址，读回同一个值 */
    volatile uint32_t *probe = (uint32_t *)0x00100000;  /* 1MB 处，恒等映射内 */
    *probe = 0xDEADBEEF;
    vga_puts("     identity map probe @1MB -> ");
    vga_hex(*probe);
    vga_putc('\n');

    /* 测试动态映射：把物理页 0x200000 映射到虚拟 0x40000000 */
    pmm_alloc_page();    /* 随便占一页，避免和上面冲突 */
    paging_map(0x40000000, 0x00200000, PAGE_RW);
    volatile uint32_t *vm = (uint32_t *)0x40000000;
    *vm = 0xCAFEBABE;
    vga_puts("     dyn map 0x40000000 -> 0x200000 : ");
    vga_hex(*vm);
    vga_putc('\n');

    vga_puts("\nSystem halted.\n");
    for (;;) __asm__ volatile("hlt");
}