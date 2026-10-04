#include "syscall.h"

static char cmd[128];
static int  cmd_len = 0;

static void putc_(char c) {
    sys_putchar(c);
}

static int str_eq(const char *a, const char *b) {
    while (*a && *b) {
        if (*a != *b) return 0;
        a++; b++;
    }
    return *a == *b;
}

static int str_prefix(const char *s, const char *pre) {
    while (*pre) {
        if (*s++ != *pre++) return 0;
    }
    return 1;
}

static void do_help(void) {
    sys_print("Commands:\n");
    sys_print("  help      - show this help\n");
    sys_print("  clear     - clear the screen\n");
    sys_print("  echo XXX  - print XXX\n");
    sys_print("  tid       - show current thread id\n");
    sys_print("  exit      - exit shell\n");
}

static void do_clear(void) {
    for (int i = 0; i < 25; i++) putc_('\n');
}

static void do_echo(const char *args) {
    sys_print(args);
    putc_('\n');
}

static void run_cmd(void) {
    cmd[cmd_len] = 0;
    putc_('\n');

    if (cmd_len == 0) {
        /* 空命令 */
    } else if (str_eq(cmd, "help")) {
        do_help();
    } else if (str_eq(cmd, "clear")) {
        do_clear();
    } else if (str_eq(cmd, "tid")) {
        int t = sys_getid();
        char b[4] = { '0' + (t % 10), '\n', 0, 0 };
        sys_print("tid = ");
        sys_print(b);
    } else if (str_eq(cmd, "exit")) {
        sys_print("Bye.\n");
        sys_exit();
    } else if (str_prefix(cmd, "echo ")) {
        do_echo(cmd + 5);
    } else {
        sys_print("unknown command: ");
        sys_print(cmd);
        putc_('\n');
    }

    cmd_len = 0;
}

int main(void) {
    sys_print("NexOS-NEXT Shell v0.1\n");
    sys_print("Type 'help' for commands.\n\n");

    for (;;) {
        sys_print("> ");
        cmd_len = 0;

        for (;;) {
            int c = sys_getchar();

            if (c == '\n') {
                run_cmd();
                break;
            } else if (c == '\b') {
                if (cmd_len > 0) {
                    cmd_len--;
                    putc_('\b');
                }
            } else if (c >= 32 && c < 127) {
                if (cmd_len < 127) {
                    cmd[cmd_len++] = (char)c;
                    putc_((char)c);
                }
            }
        }
    }
    return 0;
}