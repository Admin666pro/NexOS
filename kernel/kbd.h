#ifndef KBD_H
#define KBD_H

void kbd_init(void);
void kbd_irq(void);
int  kbd_getchar(void);
int  kbd_poll(void);
int  kbd_confirm(const char *prompt);
void kbd_wait(void);

#endif