#include "syscall.h"

int main(void) {
    sys_print("Hello from ELF-loaded userland!\n");
    sys_print("This code was loaded from an ELF file.\n");

    int tid = sys_getid();
    char buf[4] = {0};
    buf[0] = '0' + (tid % 10);
    buf[1] = '\n';
    sys_print("My tid is ");
    sys_print(buf);

    sys_exit();
    return 0;
}