#include "syscall.h"

#define MAX_PATH 256
#define MAX_NAME 64

static char cmd[128];
static int  cmd_len = 0;
static char cat_buf[256];

static void putc_(char c) { sys_putchar(c); }
static void puts_(const char *s) { while (*s) putc_(*s++); }

static int str_eq(const char *a, const char *b) {
    while (*a && *b) { if (*a != *b) return 0; a++; b++; }
    return *a == *b;
}

static int str_prefix(const char *s, const char *pre) {
    while (*pre) { if (*s++ != *pre++) return 0; }
    return 1;
}

static void skip_spaces(const char **p) {
    while (**p == ' ') (*p)++;
}

/* 从参数里取第一个词（到空格为止），写入 out */
static int take_word(const char *src, char *out, int out_size) {
    int i = 0;
    while (src[i] && src[i] != ' ' && i < out_size - 1) {
        out[i] = src[i];
        i++;
    }
    out[i] = 0;
    return i;
}

static void cmd_help(void) {
    puts_("Commands:\n");
    puts_("  help            - show this\n");
    puts_("  clear           - clear screen\n");
    puts_("  tid             - show thread id\n");
    puts_("  echo XXX        - print XXX\n");
    puts_("  ls [path]       - list directory\n");
    puts_("  cat <file>      - print file\n");
    puts_("  mkdir <dir>     - create directory\n");
    puts_("  touch <file>    - create empty file\n");
    puts_("  write <f> <txt> - write text to file\n");
    puts_("  rm <file>       - delete file\n");
    puts_("  exit            - exit shell\n");
}

static void cmd_ls(const char *args) {
    char path[MAX_PATH];
    if (!args || !*args) {
        path[0] = '/'; path[1] = 0;
    } else {
        take_word(args, path, MAX_PATH);
    }

    int fd = sys_open(path, 0);
    if (fd < 0) { puts_("ls: cannot open\n"); return; }

    for (int i = 0; ; i++) {
        char name[MAX_NAME];
        int  type = 0;
        if (sys_readdir(fd, i, name, &type) < 0) break;
        puts_(type == 2 ? "[dir]  " : "[file] ");
        puts_(name);
        putc_('\n');
    }
    sys_close(fd);
}

static void cmd_cat(const char *args) {
    if (!args || !*args) { puts_("cat: missing arg\n"); return; }
    char path[MAX_PATH];
    if (take_word(args, path, MAX_PATH) == 0) {
        puts_("cat: missing arg\n");
        return;
    }

    int fd = sys_open(path, 0);
    if (fd < 0) { puts_("cat: cannot open\n"); return; }

    for (;;) {
        int n = sys_read(fd, cat_buf, 255);
        if (n <= 0) break;
        for (int i = 0; i < n; i++) putc_(cat_buf[i]);
    }
    sys_close(fd);
}

static void cmd_mkdir(const char *args) {
    if (!args || !*args) { puts_("mkdir: missing arg\n"); return; }
    char path[MAX_PATH];
    if (take_word(args, path, MAX_PATH) == 0) {
        puts_("mkdir: missing arg\n");
        return;
    }
    if (sys_mkdir(path) < 0) puts_("mkdir: failed\n");
}

static void cmd_touch(const char *args) {
    if (!args || !*args) { puts_("touch: missing arg\n"); return; }
    char path[MAX_PATH];
    if (take_word(args, path, MAX_PATH) == 0) {
        puts_("touch: missing arg\n");
        return;
    }
    int fd = sys_open(path, 0x0100);
    if (fd < 0) puts_("touch: failed\n");
    else sys_close(fd);
}

static void cmd_write(const char *args) {
    char path[MAX_PATH];
    int used = take_word(args, path, MAX_PATH);
    if (used == 0) { puts_("write: missing file\n"); return; }

    /* 跳过文件名后的空格 */
    while (*args && *args != ' ') args++;
    skip_spaces(&args);

    int fd = sys_open(path, 0x0100 | 0x0200);   /* O_CREAT | O_TRUNC */
    if (fd < 0) { puts_("write: cannot open\n"); return; }

    int len = 0;
    while (args[len]) len++;
    if (len > 0) {
        sys_write(fd, args, len);
        sys_write(fd, "\n", 1);
    }
    sys_close(fd);
}

static void cmd_rm(const char *args) {
    if (!args || !*args) { puts_("rm: missing arg\n"); return; }
    char path[MAX_PATH];
    if (take_word(args, path, MAX_PATH) == 0) {
        puts_("rm: missing arg\n");
        return;
    }
    if (sys_unlink(path) < 0) puts_("rm: failed\n");
}

static void run_cmd(void) {
    cmd[cmd_len] = 0;
    putc_('\n');

    const char *p = cmd;
    skip_spaces(&p);

    if (cmd_len == 0) { }
    else if (str_eq(p, "help"))  cmd_help();
    else if (str_eq(p, "clear")) { for (int i = 0; i < 25; i++) putc_('\n'); }
    else if (str_eq(p, "tid")) {
        char b[4] = { '0' + (sys_getid() % 10), '\n', 0, 0 };
        puts_("tid = "); puts_(b);
    }
    else if (str_eq(p, "exit")) { puts_("Bye.\n"); sys_exit(); }
    else if (str_prefix(p, "echo ")) { puts_(p + 5); putc_('\n'); }
    else if (str_eq(p, "ls"))         cmd_ls(0);
    else if (str_prefix(p, "ls "))    cmd_ls(p + 3);
    else if (str_prefix(p, "cat "))   cmd_cat(p + 4);
    else if (str_prefix(p, "mkdir ")) cmd_mkdir(p + 6);
    else if (str_prefix(p, "touch ")) cmd_touch(p + 6);
    else if (str_prefix(p, "write ")) cmd_write(p + 6);
    else if (str_prefix(p, "rm "))    cmd_rm(p + 3);
    else { puts_("unknown: "); puts_(p); putc_('\n'); }

    cmd_len = 0;
}

int main(void) {
    puts_("NexOS-NEXT Shell v0.3\n");
    puts_("Type 'help' for commands.\n\n");

    for (;;) {
        puts_("> ");
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