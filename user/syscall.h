#ifndef USER_SYSCALL_H
#define USER_SYSCALL_H

static inline int sys_print(const char *s) {
    int r;
    __asm__ volatile("int $0x80" : "=a"(r) : "a"(1), "b"(s) : "memory");
    return r;
}

static inline void sys_exit(void) {
    __asm__ volatile("int $0x80" :: "a"(2) : "memory");
    for (;;) __asm__ volatile("pause");
}

static inline int sys_getid(void) {
    int r;
    __asm__ volatile("int $0x80" : "=a"(r) : "a"(5) : "memory");
    return r;
}

#endif