#include "syscall.h"
#include "idt.h"
#include "thread.h"
#include "sched.h"
#include "ipc.h"
#include "kbd.h"
#include "elf.h"
#include "vfs.h"
#include <stdint.h>

#define SYS_PRINT    1
#define SYS_EXIT     2
#define SYS_SEND     3
#define SYS_RECV     4
#define SYS_GETID    5
#define SYS_GETCHAR  6
#define SYS_PUTCHAR  7
#define SYS_OPEN    8
#define SYS_CLOSE   9
#define SYS_READ    10
#define SYS_WRITE   11
#define SYS_READDIR 12
#define SYS_MKDIR   13
#define SYS_UNLINK  14

extern void isr128(void);
extern void vga_putc(char c);

int syscall_handler(uint32_t num, uint32_t a, uint32_t b,
                    uint32_t c, uint32_t d, uint32_t e);

void syscall_init(void) {
    idt_set(0x80, (uint32_t)isr128, 0x08, 0xEE);
}

static int user_range_ok(uint32_t p, uint32_t len) {
    if (len == 0) return 1;
    if (p < USER_BASE) return 0;
    if (p + len < p) return 0;
    if (p + len > USER_LIMIT) return 0;
    return 1;
}

static int user_str_ok(const char *s, uint32_t maxlen) {
    if ((uint32_t)s < USER_BASE) return 0;
    for (uint32_t i = 0; i < maxlen; i++) {
        uint32_t addr = (uint32_t)s + i;
        if (addr < USER_BASE || addr >= USER_LIMIT) return 0;
        if (s[i] == 0) return 1;
    }
    return 0;
}

int syscall_handler(uint32_t num, uint32_t a, uint32_t b,
                    uint32_t c, uint32_t d, uint32_t e) {
    (void)c; (void)d; (void)e;

    switch (num) {
        case SYS_PRINT: {
            extern void vga_puts(const char *);
            if (!user_str_ok((const char *)a, 4096)) return -1;
            vga_puts((const char *)a);
            return 0;
        }
                case SYS_OPEN: {
            if (!user_str_ok((const char *)a, MAX_PATH)) return -1;
            return vfs_open((const char *)a, (int)b);
        }

        case SYS_CLOSE:
            return vfs_close((int)a);

        case SYS_READ: {
            if (!user_range_ok(b, c)) return -1;
            return vfs_fd_read((int)a, (uint8_t *)b, c);
        }

        case SYS_WRITE: {
            if (!user_range_ok(b, c)) return -1;
            return vfs_fd_write((int)a, (const uint8_t *)b, c);
        }

        case SYS_READDIR: {
            int fd  = (int)a;
            int idx = (int)b;
            if (!user_range_ok(c, MAX_NAME)) return -1;
            if (!user_range_ok(d, 4)) return -1;
            return vfs_fd_readdir(fd, idx, (char *)c, (int *)d);
        }

        case SYS_MKDIR: {
            if (!user_str_ok((const char *)a, MAX_PATH)) return -1;
            return vfs_create((const char *)a, VFS_DIR) ? 0 : -1;
        }

        case SYS_UNLINK: {
            if (!user_str_ok((const char *)a, MAX_PATH)) return -1;
            return vfs_unlink((const char *)a);
        }

        case SYS_EXIT:
            current_thread->state = THREAD_DEAD;
            sched_yield();
            return 0;

        case SYS_GETID:
            return current_thread->id;

        case SYS_GETCHAR: {
            for (;;) {
                int ch = kbd_getchar();
                if (ch >= 0) return ch;
                __asm__ volatile("sti; hlt");   /* 开中断 + 睡眠 */
            }
        }

        case SYS_PUTCHAR:
            vga_putc((char)a);
            return 0;

        case SYS_SEND: {
            int tid = (int)a;
            if (!user_range_ok(b, sizeof(user_msg_t))) return -1;
            user_msg_t *um = (user_msg_t *)b;
            message_t m = {0};
            m.sender = current_thread->id;
            m.type   = um->type;
            for (int i = 0; i < 8; i++) m.data[i] = um->data[i];
            return ipc_send(tid, &m);
        }

        case SYS_RECV: {
            if (!user_range_ok(a, sizeof(user_msg_t))) return -1;
            user_msg_t *um = (user_msg_t *)a;
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