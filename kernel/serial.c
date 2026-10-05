#include "serial.h"
#include "io.h"

#define COM1 0x3F8

void serial_init(void) {
    outb(COM1 + 1, 0x00);   /* disable interrupts */
    outb(COM1 + 3, 0x80);   /* enable DLAB */
    outb(COM1 + 0, 0x03);   /* divisor low: 38400 baud */
    outb(COM1 + 1, 0x00);   /* divisor high */
    outb(COM1 + 3, 0x03);   /* 8N1 */
    outb(COM1 + 2, 0xC7);   /* enable FIFO, clear, 14-byte */
    outb(COM1 + 4, 0x0B);   /* IRQs enabled, RTS/DSR set */
}

static int tx_ready(void) {
    return inb(COM1 + 5) & 0x20;
}

void serial_putc(char c) {
    if (c == '\n') {
        while (!tx_ready());
        outb(COM1, '\r');
    }
    while (!tx_ready());
    outb(COM1, c);
}

void serial_puts(const char *s) {
    while (*s) serial_putc(*s++);
}