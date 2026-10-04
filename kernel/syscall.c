#include "syscall.h"
#include "idt.h"
#include "thread.h"
#include "sched.h"
#include "ipc.h"
#include <stdint.h>

#define SYS_PRINT  1
#define SYS_EXIT   2
#define SYS_SEND   3
#define SYS_RECV   4
#define SYS_GETID  5

extern void isr128(void);
extern void vga_puts(const char *);
extern void vga_putc(char);

int syscall_handler(uint32_t num, uint32_t a, uint32_t b,
                    uint32_t c, uint32_t d, uint32_t e);

void syscall_init(void) {
    idt_set(0x80, (uint32_t)isr128, 0x08, 0xEE);
}

int syscall_handler(uint32_t num, uint32_t a, uint32_t b,
                    uint32_t c, uint32_t d, uint32_t e) {
    (void)c; (void)d; (void)e;

    switch (num) {
        case SYS_PRINT:
            vga_puts((const char *)a);
            return 0;

        case SYS_EXIT:
            current_thread->state = THREAD_DEAD;
            sched_yield();
            return 0;

        case SYS_GETID:
            return current_thread->id;

        case SYS_SEND: {
            int tid = (int)a;
            user_msg_t *um = (user_msg_t *)b;
            if (!um) return -1;

            /* ★ 调试：打印收到的数据 */
            extern void vga_hex(uint32_t);
            vga_puts("[K] SYS_SEND tid=");
            vga_hex(tid);
            vga_puts(" data[0]=");
            vga_hex(um->data[0]);
            vga_puts(" data[1]=");
            vga_hex(um->data[1]);
            vga_putc('\n');

            message_t m = {0};
            m.sender = current_thread->id;
            m.type   = um->type;
            for (int i = 0; i < 8; i++) m.data[i] = um->data[i];
            return ipc_send(tid, &m);
        }

        case SYS_RECV: {
            user_msg_t *um = (user_msg_t *)a;
            if (!um) return -1;
            message_t m;
            ipc_recv(&m);
            um->sender = m.sender;
            um->type   = m.type;
            for (int i = 0; i < 8; i++) um->data[i] = m.data[i];
            return 0;
        }

        default:
            return -1;
    }
}