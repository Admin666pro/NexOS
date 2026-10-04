; 主流程: 检测系统 → 安装向导 或 桌面/shell
kmain:
%ifndef LIVE
    call hd_has_system
    jc .desktop
    call install_os
%endif
.desktop:
    call gui_main
    jmp shell_loop