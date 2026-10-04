// ipc.h
#ifndef IPC_H
#define IPC_H

#include "thread.h"

int  ipc_send(int tid, message_t *msg);
void ipc_recv(message_t *out);

#endif