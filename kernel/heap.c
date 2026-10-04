#include "heap.h"
#include "pmm.h"
#include "paging.h"

#define HEAP_START    0xD0000000
#define HEAP_MAX_SIZE (16 * 1024 * 1024)
#define BLOCK_MAGIC   0x4E78534F

typedef struct block {
    uint32_t      size;    /* 总大小，含头部 */
    uint32_t      magic;
    uint32_t      free;    /* 0=已用, 1=空闲 */
    struct block *next;
} __attribute__((packed)) block_t;

static block_t *head = 0;
static uint32_t heap_mapped = 0;

#define HEAP_GROW_PAGES 16

static void heap_grow(void) {
    if (heap_mapped >= HEAP_MAX_SIZE) return;

    uint32_t virt = HEAP_START + heap_mapped;

    /* 逐页分配物理页，映射到连续的虚拟地址上 */
    for (int i = 0; i < HEAP_GROW_PAGES; i++) {
        void *phys = pmm_alloc_page();
        if (!phys) {
            /* 失败：回滚已映射的页 */
            for (int j = 0; j < i; j++) {
                /* 这里简化处理：不精确回滚，只标记 heap_mapped 不变 */
            }
            return;
        }
        paging_map(virt + i * PAGE_SIZE, (uint32_t)phys, PAGE_RW);
    }

    block_t *nb = (block_t *)virt;
    nb->size  = PAGE_SIZE * HEAP_GROW_PAGES;
    nb->magic = BLOCK_MAGIC;
    nb->free  = 1;
    nb->next  = head;
    head      = nb;

    heap_mapped += PAGE_SIZE * HEAP_GROW_PAGES;
}

void heap_init(void) {
    heap_grow();
}

void *kmalloc(uint32_t size) {
    if (size == 0) return 0;
    size = (size + 7) & ~7u;
    uint32_t need = size + sizeof(block_t);

    block_t *b = head;
    while (b) {
        if (b->free && b->size >= need) {
            if (b->size >= need + sizeof(block_t) + 16) {
                block_t *nb = (block_t *)((uint32_t)b + need);
                nb->size  = b->size - need;
                nb->magic = BLOCK_MAGIC;
                nb->free  = 1;
                nb->next  = b->next;
                b->size   = need;
                b->next   = nb;
            }
            b->free = 0;
            return (void *)((uint32_t)b + sizeof(block_t));
        }
        b = b->next;
    }

    uint32_t before = heap_mapped;
    heap_grow();
    if (heap_mapped == before) return 0;
    return kmalloc(size);
}

void kfree(void *ptr) {
    if (!ptr) return;
    block_t *b = (block_t *)((uint32_t)ptr - sizeof(block_t));
    if (b->magic != BLOCK_MAGIC) return;
    b->free = 1;

    /* 合并相邻空闲块 */
    b = head;
    while (b) {
        if (b->free && b->next && b->next->free) {
            block_t *nx = b->next;
            if ((uint32_t)b + b->size == (uint32_t)nx) {
                b->size += nx->size;
                b->next  = nx->next;
                continue;
            }
        }
        b = b->next;
    }
}