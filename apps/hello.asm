; 内置 HELLO.C0W
hello_code:
    mov si,hello_msg
    call print
    ret
hello_msg  db 'Hello from NexDOS C0W!',13,10,0
hello_size equ $ - hello_code