#ifndef BLOCK_CACHE_H
#define BLOCK_CACHE_H

#include <stdint.h>

#define BC_NUM_SLOTS     32
#define BC_BLOCK_SIZE    4096
#define BC_BLOCK_SECTORS (BC_BLOCK_SIZE / 512)

void bc_init(uint32_t data_start_lba);
int  bc_ready(void); 
int  bc_read_block(uint32_t block_no, void *out_buf);
int  bc_write_block(uint32_t block_no, const void *in_buf);
int  bc_flush(void);
int  bc_flush_block(uint32_t block_no);

#endif