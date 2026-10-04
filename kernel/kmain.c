#include <stdint.h>
#include "gdt.h"
#include "idt.h"

#define VGA_MEMORY ((volatile uint16_t *)0xB8000)
static int cursor = 0;

void vga_putc(char c) {
    if (c == '\n') { cursor = (cursor / 80 + 1) * 80; return; }
    VGA_MEMORY[cursor++] = (uint16_t)((0x07 << 8) | (uint8_t)c);
    if (cursor >= 80 * 25) cursor = 0;
}
void vga_puts(const char *s) { while (*s) vga_putc(*s++); }
void vga_hex(uint32_t v) {
    const char *h = "0123456789ABCDEF";
    vga_puts("0x");
    for (int i = 28; i >= 0; i -= 4) vga_putc(h[(v >> i) & 0xF]);
}

void kmain(uint32_t magic, uint32_t mbi) {
    (void)magic; (void)mbi;

    gdt_init();
    idt_init();

    vga_puts("NexOS 32-bit kernel booted!\n");
    vga_puts("[OK] GDT loaded\n");
    vga_puts("[OK] IDT loaded, PIC remapped\n");
    vga_puts("[OK] Interrupts enabled\n\n");

    __asm__ volatile("sti");

    vga_puts("Testing divide-by-zero in 3s...\n");
    for (volatile uint32_t i = 0; i < 200000000; i++);

    vga_puts("Triggering exception now:\n");
    volatile int a = 1, b = 0;
    volatile int c = a / b;
    (void)c;

    for (;;) __asm__ volatile("hlt");
}