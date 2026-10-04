#ifndef RAMFS_H
#define RAMFS_H

#include "vfs.h"

int          ramfs_init(void);
vfs_node_t  *ramfs_root(void);
fs_driver_t *ramfs_driver(void);

#endif