// timer.c
#include "timer.h"
#include "io.h"
#include "sched.h"

#define PIT_FREQ  1193182
#define TARGET_HZ 100

void timer_init(void) {
    uint32_t divisor = PIT_FREQ / TARGET_HZ;

    outb(0x43, 0x36);                       /* 通道 0，模式 3，二进制 */
    outb(0x40, divisor & 0xFF);
    outb(0x40, (divisor >> 8) & 0xFF);
}

void timer_tick(void) {
    sched_tick();
}