#ifndef KBD_H
#define KBD_H

void kbd_init(void);
void kbd_irq(void);
int  kbd_getchar(void);
void kbd_wait(void);

#endif