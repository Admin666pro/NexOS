#include "thread.h"

int g_receiver_tid = -1;

/* SYS_* 用宏代替 */
#define SYS_PRINT  1
#define SYS_EXIT   2
#define SYS_SEND   3
#define SYS_RECV   4

void user_receiver(void) {
    __asm__ volatile("int $0x80" :: "a"(SYS_PRINT), "b"("[R] user receiver started\n") : "memory");

    for (int i = 0; i < 5; i++) {
        user_msg_t m = {0};
        __asm__ volatile("int $0x80" :: "a"(SYS_RECV), "b"(&m) : "memory");

        __asm__ volatile("int $0x80" :: "a"(SYS_PRINT), "b"("[R] got: ") : "memory");
        __asm__ volatile("int $0x80" :: "a"(SYS_PRINT), "b"((const char *)m.data) : "memory");
        __asm__ volatile("int $0x80" :: "a"(SYS_PRINT), "b"("  from ") : "memory");

        char tmp[4] = {0};
        tmp[0] = '0' + (m.sender % 10);
        tmp[1] = '\n';
        __asm__ volatile("int $0x80" :: "a"(SYS_PRINT), "b"(tmp) : "memory");
    }

    __asm__ volatile("int $0x80" :: "a"(SYS_EXIT) : "memory");
    for (;;) __asm__ volatile("pause");
}

void user_sender(void) {
    for (volatile int i = 0; i < 20000000; i++);

    for (int i = 0; i < 5; i++) {
        user_msg_t m = {0};
        m.type = 1;
        char *p = (char *)m.data;
        p[0]='m'; p[1]='s'; p[2]='g'; p[3]='-';
        p[4]='0'+i; p[5]=0;

        __asm__ volatile("int $0x80" :: "a"(SYS_PRINT), "b"("[S] sending msg\n") : "memory");
        int tid = g_receiver_tid;
        __asm__ volatile("int $0x80" :: "a"(SYS_SEND), "b"(tid), "c"(&m) : "memory");

        for (volatile int j = 0; j < 5000000; j++);
    }
    __asm__ volatile("int $0x80" :: "a"(SYS_EXIT) : "memory");
    for (;;) __asm__ volatile("pause");
}