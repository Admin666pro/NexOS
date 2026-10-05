#ifndef ATA_H
#define ATA_H

#include <stdint.h>

#define ATA_SECTOR_SIZE 512

#define ATA_DRIVE_MASTER  0
#define ATA_DRIVE_SLAVE   1

int ata_init(void);

int ata_read_sectors_ex(int drive, uint32_t lba, uint8_t count, void *buf);
int ata_write_sectors_ex(int drive, uint32_t lba, uint8_t count, const void *buf);

/* 兼容旧调用：默认主盘 */
int ata_read_sectors(uint32_t lba, uint8_t count, void *buf);
int ata_write_sectors(uint32_t lba, uint8_t count, const void *buf);

#endif