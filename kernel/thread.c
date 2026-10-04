#include "thread.h"
#include "heap.h"
#include "sched.h"

thread_t *current_thread = 0;
static int next_id = 1;

static void thread_stub(void) {
    __asm__ volatile("sti");
    if (current_thread && current_thread->entry)
        current_thread->entry();
    for (;;) __asm__ volatile("hlt");
}

thread_t *thread_create(void (*entry)(void)) {
    thread_t *t = (thread_t *)kmalloc(sizeof(thread_t));
    if (!t) return 0;

    uint32_t *stack = (uint32_t *)kmalloc(STACK_SIZE);
    if (!stack) return 0;

    t->stack_base = stack;
    t->entry      = entry;
    t->id         = next_id++;
    t->state      = THREAD_READY;
    t->msg_head   = 0;
    t->msg_tail   = 0;
    t->next       = 0;

    uint32_t *sp = stack + (STACK_SIZE / sizeof(uint32_t));
    sp = (uint32_t *)((uint32_t)sp & ~15u);

    *--sp = (uint32_t)thread_stub;
    *--sp = 0;   /* ebp */
    *--sp = 0;   /* ebx */
    *--sp = 0;   /* esi */
    *--sp = 0;   /* edi */

    t->esp = (uint32_t)sp;

    sched_add(t);
    return t;
}

void thread_init(void) { }