extern c_kmain        ; 新加：声明 C 函数

kmain:
    call c_kmain      ; 新加：先执行 C 代码
%ifndef LIVE
    call hd_has_system
    jc .desktop
    call install_os
%endif
.desktop:
    call gui_main
    jmp shell_loop