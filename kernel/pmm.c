#include "pmm.h"

/* 4GB / 4KB = 1M 页 -> 128KB bitmap，放 BSS 里 */
#define MAX_PAGES  (1024 * 1024)
static uint8_t bitmap[MAX_PAGES / 8];

static uint32_t total_pages = 0;
static uint32_t used_pages  = 0;

struct mmap_entry {
    uint32_t size;
    uint64_t base;
    uint64_t len;
    uint32_t type;
} __attribute__((packed));

static inline void bm_set(uint32_t b)  { bitmap[b >> 3] |=  (1u << (b & 7)); }
static inline void bm_clr(uint32_t b)  { bitmap[b >> 3] &= ~(1u << (b & 7)); }
static inline int  bm_test(uint32_t b) { return (bitmap[b >> 3] >> (b & 7)) & 1u; }

extern char _kernel_start[], _kernel_end[];

void pmm_init(uint32_t mbi) {
    /* 1. 全部标记为已使用 */
    for (uint32_t i = 0; i < sizeof(bitmap); i++) bitmap[i] = 0xFF;

    /* 2. 遍历 Multiboot 内存映射 */
    uint32_t flags    = *(uint32_t *)mbi;
    uint32_t max_addr = 0;

    if (flags & (1u << 6)) {
        uint32_t mmap_len = *(uint32_t *)(mbi + 44);
        uint32_t mmap_ptr = *(uint32_t *)(mbi + 48);

        uint32_t p   = mmap_ptr;
        uint32_t end = mmap_ptr + mmap_len;

        while (p < end) {
            struct mmap_entry *e = (struct mmap_entry *)p;

            if (e->type == 1) {
                uint64_t base = e->base;
                uint64_t len  = e->len;

                /* 1MB 以下留给 BIOS/显存，跳过 */
                if (base < 0x100000) {
                    uint64_t skip = 0x100000 - base;
                    if (skip >= len) goto next;
                    base += skip;
                    len  -= skip;
                }
                /* 忽略 4GB 以上 */
                if (base >= 0x100000000ULL) goto next;
                if (base + len > 0x100000000ULL)
                    len = 0x100000000ULL - base;

                uint32_t first = (uint32_t)(base / PAGE_SIZE);
                uint32_t count = (uint32_t)(len  / PAGE_SIZE);
                for (uint32_t i = 0; i < count; i++) bm_clr(first + i);

                uint64_t top = base + len;
                if (top > max_addr) max_addr = (uint32_t)top;
            }
next:
            p += e->size + 4;
        }
    }

    total_pages = max_addr / PAGE_SIZE;

    /* 3. 把内核自身标回已使用 */
    uint32_t ks = (uint32_t)_kernel_start;
    uint32_t ke = (uint32_t)_kernel_end;
    for (uint32_t a = ks & ~(PAGE_SIZE - 1); a < ke; a += PAGE_SIZE)
        bm_set(a / PAGE_SIZE);

    /* 4. 统计已用页 */
    used_pages = 0;
    for (uint32_t i = 0; i < total_pages; i++)
        if (bm_test(i)) used_pages++;
}

void *pmm_alloc_page(void) {
    for (uint32_t i = 0; i < total_pages; i++) {
        if (!bm_test(i)) {
            bm_set(i);
            used_pages++;
            return (void *)(i * PAGE_SIZE);
        }
    }
    return 0;
}

void pmm_free_page(void *addr) {
    uint32_t page = (uint32_t)addr / PAGE_SIZE;
    if (page < total_pages && bm_test(page)) {
        bm_clr(page);
        used_pages--;
    }
}

uint32_t pmm_total_pages(void) { return total_pages; }
uint32_t pmm_used_pages(void)  { return used_pages; }