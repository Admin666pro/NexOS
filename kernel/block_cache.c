#include "block_cache.h"
#include "ata.h"
#include "heap.h"

typedef struct {
    uint32_t block_no;      /* 0xFFFFFFFF = 空闲槽 */
    uint32_t age;           /* LRU 用，越大越新 */
    int      dirty;
    uint8_t *data;          /* BC_BLOCK_SIZE 字节 */
} bc_slot_t;

static bc_slot_t slots[BC_NUM_SLOTS];
static uint32_t  age_counter = 0;
static uint32_t  data_lba = 0;
static int       initialized = 0;

void bc_init(uint32_t lba) {
    data_lba = lba;
    age_counter = 0;
    initialized = 0;

    for (int i = 0; i < BC_NUM_SLOTS; i++) {
        slots[i].block_no = 0xFFFFFFFFu;
        slots[i].age = 0;
        slots[i].dirty = 0;
        slots[i].data = (uint8_t *)kmalloc(BC_BLOCK_SIZE);
        if (!slots[i].data) return;
    }
    initialized = 1;
}

int bc_ready(void) { return initialized; }

static int raw_read(uint32_t block_no, void *buf) {
    extern uint32_t NXFS_PART_LBA_val(void);  /* 或直接引外部变量 */
    uint32_t lba = data_lba + block_no * BC_BLOCK_SECTORS;
    return ata_read_sectors(lba, BC_BLOCK_SECTORS, buf);
}

static int raw_write(uint32_t block_no, const void *buf) {
    uint32_t lba = data_lba + block_no * BC_BLOCK_SECTORS;
    return ata_write_sectors(lba, BC_BLOCK_SECTORS, buf);
}

static bc_slot_t *find_slot(uint32_t block_no) {
    for (int i = 0; i < BC_NUM_SLOTS; i++) {
        if (slots[i].block_no == block_no) return &slots[i];
    }
    return 0;
}

/* 分配一个槽：优先用空闲，否则淘汰最旧的槽（脏的先刷盘） */
static bc_slot_t *alloc_slot(void) {
    for (int i = 0; i < BC_NUM_SLOTS; i++) {
        if (slots[i].block_no == 0xFFFFFFFFu) return &slots[i];
    }

    bc_slot_t *oldest = &slots[0];
    for (int i = 1; i < BC_NUM_SLOTS; i++) {
        if (slots[i].age < oldest->age) oldest = &slots[i];
    }

    if (oldest->dirty) {
        if (raw_write(oldest->block_no, oldest->data) < 0)
            return 0;
    }
    return oldest;
}

int bc_read_block(uint32_t block_no, void *out_buf) {
    if (!initialized) return -1;

    bc_slot_t *s = find_slot(block_no);
    if (s) {
        s->age = ++age_counter;
        for (int i = 0; i < BC_BLOCK_SIZE; i++)
            ((uint8_t *)out_buf)[i] = s->data[i];
        return 0;
    }

    s = alloc_slot();
    if (!s) return -1;

    if (raw_read(block_no, s->data) < 0) return -2;

    s->block_no = block_no;
    s->age = ++age_counter;
    s->dirty = 0;

    for (int i = 0; i < BC_BLOCK_SIZE; i++)
        ((uint8_t *)out_buf)[i] = s->data[i];
    return 0;
}

int bc_write_block(uint32_t block_no, const void *in_buf) {
    if (!initialized) return -1;

    bc_slot_t *s = find_slot(block_no);
    if (!s) {
        s = alloc_slot();
        if (!s) return -1;

        /* 先读原内容（保证部分写不会丢块内其他数据） */
        if (raw_read(block_no, s->data) < 0) return -2;

        s->block_no = block_no;
    }

    s->age = ++age_counter;
    s->dirty = 1;
    for (int i = 0; i < BC_BLOCK_SIZE; i++)
        s->data[i] = ((const uint8_t *)in_buf)[i];
    return 0;
}

int bc_flush_block(uint32_t block_no) {
    if (!initialized) return -1;
    bc_slot_t *s = find_slot(block_no);
    if (!s || !s->dirty) return 0;
    if (raw_write(block_no, s->data) < 0) return -1;
    s->dirty = 0;
    return 0;
}

int bc_flush(void) {
    if (!initialized) return -1;
    int fail = 0;
    for (int i = 0; i < BC_NUM_SLOTS; i++) {
        if (slots[i].block_no == 0xFFFFFFFFu) continue;
        if (!slots[i].dirty) continue;
        if (raw_write(slots[i].block_no, slots[i].data) < 0) fail = -1;
        else slots[i].dirty = 0;
    }
    return fail;
}