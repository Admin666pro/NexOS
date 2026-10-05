#include "part.h"
#include "ata.h"

#define MBR_LBA       0
#define MBR_SIG_0     0x55
#define MBR_SIG_1     0xAA
#define PART_OFFSET   0x1BE
#define PART_SIZE     16

/* 把 MBR 分成 4 个分区项解析 */
int part_read_table(int drive, partition_t table[PART_ENTRIES]) {
    uint8_t mbr[512];
    if (ata_read_sectors_ex(drive, MBR_LBA, 1, mbr) < 0) return -1;

    if (mbr[510] != MBR_SIG_0 || mbr[511] != MBR_SIG_1) {
        /* 没有 MBR 签名，当作全空 */
        for (int i = 0; i < PART_ENTRIES; i++) {
            table[i].bootable  = 0;
            table[i].type      = 0;
            table[i].start_lba = 0;
            table[i].sectors   = 0;
        }
        return 0;
    }

    for (int i = 0; i < PART_ENTRIES; i++) {
        const uint8_t *p = mbr + PART_OFFSET + i * PART_SIZE;
        table[i].bootable  = (p[0] == 0x80);
        table[i].type      = p[4];
        table[i].start_lba = (uint32_t)p[8]
                           | ((uint32_t)p[9]  << 8)
                           | ((uint32_t)p[10] << 16)
                           | ((uint32_t)p[11] << 24);
        table[i].sectors   = (uint32_t)p[12]
                           | ((uint32_t)p[13] << 8)
                           | ((uint32_t)p[14] << 16)
                           | ((uint32_t)p[15] << 24);
    }
    return 0;
}

/* 把 CHS 填成无效（0xFE 0xFF 0xFF），现代系统用 LBA */
static void set_chs_invalid(uint8_t *chs) {
    chs[0] = 0xFE;
    chs[1] = 0xFF;
    chs[2] = 0xFF;
}

int part_write_table(int drive, const partition_t table[PART_ENTRIES]) {
    uint8_t mbr[512];

    /* 读原 MBR，保留引导代码 */
    if (ata_read_sectors_ex(drive, MBR_LBA, 1, mbr) < 0) return -1;

    /* 只在签名丢失时清零 */
    if (mbr[510] != MBR_SIG_0 || mbr[511] != MBR_SIG_1) {
        for (int i = 0; i < 512; i++) mbr[i] = 0;
    }

    for (int i = 0; i < PART_ENTRIES; i++) {
        uint8_t *p = mbr + PART_OFFSET + i * PART_SIZE;

        for (int j = 0; j < PART_SIZE; j++) p[j] = 0;

        if (table[i].type == 0 || table[i].sectors == 0) continue;

        p[0] = table[i].bootable ? 0x80 : 0x00;
        set_chs_invalid(p + 1);          /* CHS start */
        p[4] = (uint8_t)table[i].type;
        set_chs_invalid(p + 5);          /* CHS end */
        p[8]  = table[i].start_lba & 0xFF;
        p[9]  = (table[i].start_lba >> 8) & 0xFF;
        p[10] = (table[i].start_lba >> 16) & 0xFF;
        p[11] = (table[i].start_lba >> 24) & 0xFF;
        p[12] = table[i].sectors & 0xFF;
        p[13] = (table[i].sectors >> 8) & 0xFF;
        p[14] = (table[i].sectors >> 16) & 0xFF;
        p[15] = (table[i].sectors >> 24) & 0xFF;
    }

    mbr[510] = MBR_SIG_0;
    mbr[511] = MBR_SIG_1;

    return ata_write_sectors_ex(drive, MBR_LBA, 1, mbr);
}

int part_set_entry(int drive, int index, const partition_t *ent) {
    if (index < 0 || index >= PART_ENTRIES) return -1;
    partition_t table[PART_ENTRIES];
    if (part_read_table(drive, table) < 0) return -1;
    table[index] = *ent;
    return part_write_table(drive, table);
}

int part_clear(int drive) {
    partition_t table[PART_ENTRIES];
    for (int i = 0; i < PART_ENTRIES; i++) {
        table[i].bootable  = 0;
        table[i].type      = 0;
        table[i].start_lba = 0;
        table[i].sectors   = 0;
    }
    return part_write_table(drive, table);
}