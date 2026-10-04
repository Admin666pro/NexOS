// sched.c
#include "sched.h"

#define MAX_THREADS 64

static thread_t *threads[MAX_THREADS];
static int       thread_count = 0;
static int       current_idx  = 0;

/* 供 IPC 使用 */
thread_t *sched_find(int tid) {
    for (int i = 0; i < thread_count; i++)
        if (threads[i]->id == tid) return threads[i];
    return 0;
}

void sched_add(thread_t *t) {
    if (thread_count < MAX_THREADS)
        threads[thread_count++] = t;
}

/* 找下一个 READY 线程，返回 -1 表示没有 */
static int next_ready(int from) {
    for (int i = 1; i <= thread_count; i++) {
        int idx = (from + i) % thread_count;
        if (threads[idx]->state == THREAD_READY) return idx;
    }
    return -1;
}

void sched_tick(void) {
    if (thread_count < 2 || !current_thread) return;

    int next = next_ready(current_idx);
    if (next < 0 || next == current_idx) return;

    int old_idx = current_idx;
    current_idx = next;

    thread_t *old  = threads[old_idx];
    thread_t *nxt  = threads[next];

    current_thread = nxt;
    switch_to(&old->esp, nxt->esp);
}

void sched_yield(void) {
    if (thread_count < 2 || !current_thread) return;

    int next = next_ready(current_idx);
    if (next < 0) return;   /* 全阻塞：留在当前，等中断唤醒 */

    int old_idx = current_idx;
    current_idx = next;

    thread_t *old = threads[old_idx];
    thread_t *nxt = threads[next];

    current_thread = nxt;
    switch_to(&old->esp, nxt->esp);
}

void sched_start(void) {
    if (thread_count == 0) {
        extern void vga_puts(const char *);
        vga_puts("[FATAL] sched_start: no threads\n");
        for (;;) __asm__ volatile("hlt");
    }

    current_idx    = 0;
    current_thread = threads[0];

    uint32_t dummy;
    switch_to(&dummy, current_thread->esp);
    for (;;) __asm__ volatile("hlt");
}