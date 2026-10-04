#ifndef THREAD_H
#define THREAD_H

#include <stdint.h>

#define STACK_SIZE 2048

typedef enum { THREAD_READY, THREAD_BLOCKED } thread_state_t;

typedef struct message {
    int       sender;
    int       type;
    uint32_t  data[8];
    struct message *next;
} message_t;

typedef struct thread {
    uint32_t       esp;
    uint32_t      *stack_base;
    void         (*entry)(void);
    int            id;
    int            state;
    message_t     *msg_head;
    message_t     *msg_tail;
    struct thread *next;
} thread_t;

thread_t *thread_create(void (*entry)(void));
void      thread_init(void);

extern thread_t *current_thread;

void switch_to(uint32_t *old_esp_ptr, uint32_t new_esp);

#endif