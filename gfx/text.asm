; 文本输出, 两套模式:
;   print/newline    -> BIOS int 0x10, ah=0x0E (文本模式)
;   draw_text/next_line -> VGA 像素渲染 (图形模式)

print:
    push ax
    push bx
.p_l:
    lodsb
    or al,al
    jz .p_d
    mov ah,0x0E
    mov bx,7
    int 0x10
    jmp .p_l
.p_d:
    pop bx
    pop ax
    ret

newline:
    push ax
    push bx
    mov ah,0x0E
    mov al,13
    mov bx,7
    int 0x10
    mov al,10
    int 0x10
    pop bx
    pop ax
    ret

; draw_text: SI=GB2312 串, 起点 txt_x/txt_y, 自动换行
draw_text:
    push ax
    push cx
    push dx
    push si
    mov cx,[txt_x]
    mov dx,[txt_y]
.dt_l:
    lodsb
    or al,al
    jz .dt_d
    cmp al,13
    je .dt_nl
    cmp al,10
    je .dt_l
    cmp al,0x20
    jb .dt_l
    cmp al,0x7F
    jae .dt_han
    mov ah,al
    call draw_char_asc
    add cx,8
    jmp .dt_l
.dt_han:
    mov ah,[si]
    inc si
    call draw_char_han
    add cx,16
    jmp .dt_l
.dt_nl:
    mov word [txt_x],0
    mov ax,[txt_y]
    add ax,16
    mov [txt_y],ax
    mov cx,0
    mov dx,ax
    jmp .dt_l
.dt_d:
    mov [txt_x],cx
    mov [txt_y],dx
    pop si
    pop dx
    pop cx
    pop ax
    ret

; next_line: 光标下移一行, x 归零
next_line:
    push ax
    mov ax,[txt_y]
    add ax,16
    mov [txt_y],ax
    mov word [txt_x],0
    pop ax
    ret