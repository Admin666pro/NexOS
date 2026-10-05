#ifndef PART_H
#define PART_H

#include <stdint.h>

#define PART_ENTRIES  4

typedef struct {
    int      bootable;
    int      type;
    uint32_t start_lba;
    uint32_t sectors;
} partition_t;

/* 读 MBR 分区表 */
int part_read_table(int drive, partition_t table[PART_ENTRIES]);

/* 写 MBR 分区表（保留引导代码） */
int part_write_table(int drive, const partition_t table[PART_ENTRIES]);

/* 写单个分区项（其他项不变） */
int part_set_entry(int drive, int index, const partition_t *ent);

/* 清空所有分区项 */
int part_clear(int drive);

#endif