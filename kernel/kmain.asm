extern c_kmain_        ; 注意末尾下划线

global kmain           ; 如果 kmain 需要被外部引用，加上 global

global main_
main_:
    jmp kmain

kmain:
    call c_kmain_      ; 同样加下划线
%ifndef LIVE
    call hd_has_system
    jc .desktop
    call install_os
%endif
.desktop:
    call gui_main
    jmp shell_loop