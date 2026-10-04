#include "sched.h"

extern void gdt_set_kernel_stack(uint32_t esp0);

#define MAX_THREADS 64

static thread_t *threads[MAX_THREADS];
static int       thread_count = 0;
static int       current_idx  = 0;

/* 给 IPC 用 */
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

/* 统一的上下文切换：更新 TSS esp0，再 switch_to */
static void do_switch(int old_idx, int new_idx) {
    thread_t *old = threads[old_idx];
    thread_t *nxt = threads[new_idx];

    /* 更新 TSS 的 esp0，让 ring 3 进 ring 0 时能切到正确的内核栈 */
    uint32_t *ks = nxt->kernel_stack ? nxt->kernel_stack : nxt->stack_base;
    if (ks) gdt_set_kernel_stack((uint32_t)ks + STACK_SIZE);

    current_thread = nxt;
    switch_to(&old->esp, nxt->esp);
}

void sched_tick(void) {
    if (thread_count < 2 || !current_thread) return;

    int next = next_ready(current_idx);
    if (next < 0 || next == current_idx) return;

    int old_idx = current_idx;
    current_idx = next;
    do_switch(old_idx, next);
}

void sched_yield(void) {
    if (thread_count < 2 || !current_thread) return;

    int next = next_ready(current_idx);
    if (next < 0) {
        /* 没有可运行线程，切回内核主流程 */
        extern void vga_puts(const char *);
        vga_puts("\n[KERNEL] all threads dead, halting\n");
        for (;;) __asm__ volatile("hlt");
    }

    int old_idx = current_idx;
    current_idx = next;
    do_switch(old_idx, next);
}

void sched_start(void) {
    if (thread_count == 0) {
        extern void vga_puts(const char *);
        vga_puts("[FATAL] sched_start: no threads\n");
        for (;;) __asm__ volatile("hlt");
    }

    current_idx    = 0;
    current_thread = threads[0];

    /* 首次切换前也要设置 esp0 */
    uint32_t *ks = current_thread->kernel_stack
                 ? current_thread->kernel_stack
                 : current_thread->stack_base;
    if (ks) gdt_set_kernel_stack((uint32_t)ks + STACK_SIZE);

    uint32_t dummy;
    switch_to(&dummy, current_thread->esp);
    for (;;) __asm__ volatile("hlt");
}