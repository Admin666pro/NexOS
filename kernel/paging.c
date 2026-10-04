#include "paging.h"
#include "pmm.h"

#define PD_INDEX(v)  ((v) >> 22)
#define PT_INDEX(v)  (((v) >> 12) & 0x3FF)

static uint32_t *page_dir = 0;

extern void paging_load_dir(uint32_t);

/* 恒等映射前 16MB —— 足够内核 + VGA + PMM bitmap */
#define IDENTITY_SIZE  (16 * 1024 * 1024)

void paging_init(void) {
    page_dir = (uint32_t *)pmm_alloc_page();
    for (int i = 0; i < 1024; i++) page_dir[i] = 0;

    for (uint32_t addr = 0; addr < IDENTITY_SIZE; addr += 0x400000) {
        uint32_t *pt = (uint32_t *)pmm_alloc_page();
        for (int i = 0; i < 1024; i++)
            pt[i] = (addr + i * 0x1000) | PAGE_PRESENT | PAGE_RW;
        page_dir[PD_INDEX(addr)] = ((uint32_t)pt) | PAGE_PRESENT | PAGE_RW;
    }

    paging_load_dir((uint32_t)page_dir);
}

void paging_map(uint32_t virt, uint32_t phys, uint32_t flags) {
    uint32_t pd = PD_INDEX(virt);
    uint32_t pt = PT_INDEX(virt);

    if (!(page_dir[pd] & PAGE_PRESENT)) {
        uint32_t *new_pt = (uint32_t *)pmm_alloc_page();
        for (int i = 0; i < 1024; i++) new_pt[i] = 0;

        /* 页目录项权限：只有 flags 里带 PAGE_USER 时才允许用户访问 */
        uint32_t pd_flags = PAGE_PRESENT | PAGE_RW;
        if (flags & PAGE_USER) pd_flags |= PAGE_USER;

        page_dir[pd] = ((uint32_t)new_pt) | pd_flags;
    }

    uint32_t *table = (uint32_t *)(page_dir[pd] & ~0xFFF);
    table[pt] = (phys & ~0xFFF) | (flags & 0xFFF) | PAGE_PRESENT;
    __asm__ volatile("invlpg (%0)" :: "r"(virt) : "memory");
}

uint32_t *paging_get_dir(void) { return page_dir; }