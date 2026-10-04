#include "cdefs.h"

void *memset(void *s, int c, unsigned int n) {
    u8 *p = (u8 *)s;
    while (n--) *p++ = (u8)c;
    return s;
}

void *memcpy(void *d, const void *s, unsigned int n) {
    u8 *dp = (u8 *)d;
    const u8 *sp = (const u8 *)s;
    while (n--) *dp++ = *sp++;
    return d;
}

void *memmove(void *d, const void *s, unsigned int n) {
    u8 *dp = (u8 *)d;
    const u8 *sp = (const u8 *)s;
    if (dp < sp) {
        while (n--) *dp++ = *sp++;
    } else {
        dp += n; sp += n;
        while (n--) *--dp = *--sp;
    }
    return d;
}

int memcmp(const void *a, const void *b, unsigned int n) {
    const u8 *pa = a, *pb = b;
    while (n--) {
        if (*pa != *pb) return *pa - *pb;
        pa++; pb++;
    }
    return 0;
}