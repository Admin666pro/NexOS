#ifndef PAGING_H
#define PAGING_H

#include <stdint.h>

#define PAGE_PRESENT  0x01
#define PAGE_RW       0x02
#define PAGE_USER     0x04

void paging_init(void);
void paging_map(uint32_t virt, uint32_t phys, uint32_t flags);
uint32_t *paging_get_dir(void);

#endif