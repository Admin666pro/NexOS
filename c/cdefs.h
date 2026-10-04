#ifndef CDEFS_H
#define CDEFS_H

#define WATCALL __watcall

typedef unsigned char  u8;
typedef unsigned short u16;
typedef unsigned long  u32;

/* 汇编 wrapper 提供的接口 */
extern void WATCALL c_puts(const char *s);
extern void WATCALL c_putc(char c);
extern void WATCALL c_newline(void);
extern void WATCALL c_cls(void);

/* C 主入口, 被汇编的 kmain 调用 */
void c_kmain(void);

#endif