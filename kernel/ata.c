#include "ata.h"
#include "io.h"

#define ATA_PRIMARY_IO    0x1F0
#define ATA_PRIMARY_CTRL  0x3F6

#define ATA_REG_DATA      0
#define ATA_REG_SECCOUNT  2
#define ATA_REG_LBA_LO    3
#define ATA_REG_LBA_MID   4
#define ATA_REG_LBA_HI    5
#define ATA_REG_DRIVE     6
#define ATA_REG_STATUS    7
#define ATA_REG_COMMAND   7

#define ATA_SR_BSY  0x80
#define ATA_SR_DRDY 0x40
#define ATA_SR_DF   0x20
#define ATA_SR_DRQ  0x08
#define ATA_SR_ERR  0x01

#define ATA_CMD_READ_PIO    0x20
#define ATA_CMD_WRITE_PIO   0x30
#define ATA_CMD_IDENTIFY    0xEC
#define ATA_CMD_CACHE_FLUSH 0xE7

static void ata_400ns_delay(void) {
    inb(ATA_PRIMARY_IO + ATA_REG_STATUS);
    inb(ATA_PRIMARY_IO + ATA_REG_STATUS);
    inb(ATA_PRIMARY_IO + ATA_REG_STATUS);
    inb(ATA_PRIMARY_IO + ATA_REG_STATUS);
}

static int ata_wait_bsy(void) {
    for (int i = 0; i < 1000000; i++) {
        if (!(inb(ATA_PRIMARY_IO + ATA_REG_STATUS) & ATA_SR_BSY))
            return 0;
    }
    return -1;
}

static int ata_wait_drq(void) {
    for (int i = 0; i < 1000000; i++) {
        uint8_t s = inb(ATA_PRIMARY_IO + ATA_REG_STATUS);
        if (s & ATA_SR_ERR) return -1;
        if (s & ATA_SR_DF)  return -2;
        if (s & ATA_SR_DRQ) return 0;
    }
    return -3;
}

/* 选中盘并等待就绪，返回 0 成功 */
static int ata_select(int drive) {
    uint8_t sel = (drive == ATA_DRIVE_MASTER) ? 0xA0 : 0xB0;
    outb(ATA_PRIMARY_IO + ATA_REG_DRIVE, sel);
    ata_400ns_delay();

    for (int i = 0; i < 100000; i++) {
        uint8_t s = inb(ATA_PRIMARY_IO + ATA_REG_STATUS);
        if (s == 0) return -1;          /* 设备不存在 */
        if (s & ATA_SR_ERR) return -1;
        if (!(s & ATA_SR_BSY) && (s & ATA_SR_DRDY)) return 0;
    }
    return -1;
}

/* 探测并识别主盘，进入已知状态 */
static int ata_identify(int drive) {
    if (ata_select(drive) < 0) return -1;

    outb(ATA_PRIMARY_IO + ATA_REG_SECCOUNT, 0);
    outb(ATA_PRIMARY_IO + ATA_REG_LBA_LO,   0);
    outb(ATA_PRIMARY_IO + ATA_REG_LBA_MID,  0);
    outb(ATA_PRIMARY_IO + ATA_REG_LBA_HI,   0);
    outb(ATA_PRIMARY_IO + ATA_REG_COMMAND,  ATA_CMD_IDENTIFY);

    uint8_t s = inb(ATA_PRIMARY_IO + ATA_REG_STATUS);
    if (s == 0) return -1;   /* 无设备 */

    if (ata_wait_bsy() < 0) return -1;

    /* ATAPI 设备会在这里返回非零 */
    if (inb(ATA_PRIMARY_IO + ATA_REG_LBA_MID) != 0) return -1;
    if (inb(ATA_PRIMARY_IO + ATA_REG_LBA_HI)  != 0) return -1;

    if (ata_wait_drq() < 0) return -1;

    /* 读走 256 字 identify 数据 */
    for (int i = 0; i < 256; i++) inw(ATA_PRIMARY_IO + ATA_REG_DATA);

    return 0;
}

int ata_init(void) {
    /* 软复位 */
    outb(ATA_PRIMARY_CTRL, 0x04);
    ata_400ns_delay();
    outb(ATA_PRIMARY_CTRL, 0x00);
    ata_400ns_delay();

    /* 探测主盘 */
    if (ata_identify(ATA_DRIVE_MASTER) < 0) return -1;

    return 0;
}

int ata_read_sectors_ex(int drive, uint32_t lba, uint8_t count, void *buf) {
    if (count == 0) return 0;

    uint8_t sel = (drive == ATA_DRIVE_MASTER) ? 0xE0 : 0xF0;

    if (ata_wait_bsy() < 0) return -1;

    outb(ATA_PRIMARY_IO + ATA_REG_DRIVE, sel | ((lba >> 24) & 0x0F));
    ata_400ns_delay();

    outb(ATA_PRIMARY_IO + ATA_REG_SECCOUNT, count);
    outb(ATA_PRIMARY_IO + ATA_REG_LBA_LO,   (uint8_t)(lba & 0xFF));
    outb(ATA_PRIMARY_IO + ATA_REG_LBA_MID,  (uint8_t)((lba >> 8) & 0xFF));
    outb(ATA_PRIMARY_IO + ATA_REG_LBA_HI,   (uint8_t)((lba >> 16) & 0xFF));
    outb(ATA_PRIMARY_IO + ATA_REG_COMMAND,  ATA_CMD_READ_PIO);

    uint16_t *p = (uint16_t *)buf;
    for (int s = 0; s < count; s++) {
        if (ata_wait_bsy() < 0) return -2;
        if (ata_wait_drq() < 0) return -3;
        for (int i = 0; i < 256; i++)
            *p++ = inw(ATA_PRIMARY_IO + ATA_REG_DATA);
    }
    return 0;
}

int ata_write_sectors_ex(int drive, uint32_t lba, uint8_t count, const void *buf) {
    if (count == 0) return 0;

    uint8_t sel = (drive == ATA_DRIVE_MASTER) ? 0xE0 : 0xF0;

    if (ata_wait_bsy() < 0) return -1;

    outb(ATA_PRIMARY_IO + ATA_REG_DRIVE, sel | ((lba >> 24) & 0x0F));
    ata_400ns_delay();

    outb(ATA_PRIMARY_IO + ATA_REG_SECCOUNT, count);
    outb(ATA_PRIMARY_IO + ATA_REG_LBA_LO,   (uint8_t)(lba & 0xFF));
    outb(ATA_PRIMARY_IO + ATA_REG_LBA_MID,  (uint8_t)((lba >> 8) & 0xFF));
    outb(ATA_PRIMARY_IO + ATA_REG_LBA_HI,   (uint8_t)((lba >> 16) & 0xFF));
    outb(ATA_PRIMARY_IO + ATA_REG_COMMAND,  ATA_CMD_WRITE_PIO);

    const uint16_t *p = (const uint16_t *)buf;
    for (int s = 0; s < count; s++) {
        if (ata_wait_bsy() < 0) return -2;
        if (ata_wait_drq() < 0) return -3;
        for (int i = 0; i < 256; i++)
            outw(ATA_PRIMARY_IO + ATA_REG_DATA, *p++);
    }

    outb(ATA_PRIMARY_IO + ATA_REG_COMMAND, ATA_CMD_CACHE_FLUSH);
    ata_wait_bsy();
    return 0;
}

int ata_read_sectors(uint32_t lba, uint8_t count, void *buf) {
    return ata_read_sectors_ex(ATA_DRIVE_MASTER, lba, count, buf);
}

int ata_write_sectors(uint32_t lba, uint8_t count, const void *buf) {
    return ata_write_sectors_ex(ATA_DRIVE_MASTER, lba, count, buf);
}