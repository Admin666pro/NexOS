// sched.h
#ifndef SCHED_H
#define SCHED_H

#include "thread.h"

void sched_add(thread_t *t);
void sched_start(void);
void sched_tick(void);
void sched_yield(void);

#endif