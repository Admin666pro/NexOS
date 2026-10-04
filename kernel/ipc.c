// ipc.c
#include "ipc.h"
#include "sched.h"
#include "heap.h"

extern thread_t *sched_find(int tid);

int ipc_send(int tid, message_t *msg) {
    thread_t *t = sched_find(tid);
    if (!t) return -1;

    message_t *m = (message_t *)kmalloc(sizeof(message_t));
    if (!m) return -1;

    *m = *msg;
    m->next = 0;

    /* 入队 */
    if (t->msg_tail)
        t->msg_tail->next = m;
    else
        t->msg_head = m;
    t->msg_tail = m;

    /* 唤醒阻塞的接收方 */
    if (t->state == THREAD_BLOCKED)
        t->state = THREAD_READY;

    return 0;
}

void ipc_recv(message_t *out) {
    for (;;) {
        if (current_thread->msg_head) {
            message_t *m = current_thread->msg_head;
            current_thread->msg_head = m->next;
            if (!current_thread->msg_head)
                current_thread->msg_tail = 0;

            *out = *m;
            kfree(m);
            return;
        }

        /* 队列空，阻塞并让出 CPU */
        current_thread->state = THREAD_BLOCKED;
        sched_yield();
        /* 被唤醒后从这里继续，重新检查队列 */
    }
}