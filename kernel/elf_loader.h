#ifndef ELF_LOADER_H
#define ELF_LOADER_H

#include <stdint.h>

typedef struct {
    uint32_t entry;
    uint32_t stack_top;
} elf_load_result_t;

int elf_load(const void *elf_data, uint32_t elf_size, elf_load_result_t *out);

#endif