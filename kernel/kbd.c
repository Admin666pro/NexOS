#include "kbd.h"
#include "io.h"
#include "thread.h"
#include "sched.h"

#define KBD_BUF_SIZE 256

static volatile uint8_t  kbd_buf[KBD_BUF_SIZE];
static volatile uint32_t kbd_head = 0;
static volatile uint32_t kbd_tail = 0;

/* 等待键盘输入的线程（同一时刻只有一个用户态 shell） */
static thread_t *waiter = 0;

/* Scancode set 1 映射表 */
static const char scancode_map[128] = {
    0,    27,   '1',  '2',  '3',  '4',  '5',  '6',
    '7',  '8',  '9',  '0',  '-',  '=',  '\b', '\t',
    'q',  'w',  'e',  'r',  't',  'y',  'u',  'i',
    'o',  'p',  '[',  ']',  '\n', 0,    'a',  's',
    'd',  'f',  'g',  'h',  'j',  'k',  'l',  ';',
    '\'', '`',  0,    '\\', 'z',  'x',  'c',  'v',
    'b',  'n',  'm',  ',',  '.',  '/',  0,    '*',
    0,    ' ',  0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0,
    0,    0,    0,    0,    0,    0,    0,    0
};

void kbd_init(void) {
    kbd_head = 0;
    kbd_tail = 0;
    waiter   = 0;
}

void kbd_irq(void) {
    uint8_t sc = inb(0x60);

    /* 只处理按下（bit 7 = 0） */
    if (sc & 0x80) return;
    if (sc >= 128) return;

    char c = scancode_map[sc];
    if (c == 0) return;

    uint32_t next = (kbd_head + 1) % KBD_BUF_SIZE;
    if (next == kbd_tail) return;    /* 缓冲区满，丢弃 */
    kbd_buf[kbd_head] = (uint8_t)c;
    kbd_head = next;

    /* 唤醒阻塞中的等待者 */
    if (waiter) {
        if (waiter->state == THREAD_BLOCKED)
            waiter->state = THREAD_READY;
        waiter = 0;
    }
}

int kbd_getchar(void) {
    if (kbd_head == kbd_tail) return -1;
    char c = (char)kbd_buf[kbd_tail];
    kbd_tail = (kbd_tail + 1) % KBD_BUF_SIZE;
    return (int)c;
}

void kbd_wait(void) {
    waiter = current_thread;
    current_thread->state = THREAD_BLOCKED;
    sched_yield();
}