; 内置 README.TXT
readme_code:
    db 'Welcome to NexDOS v1.0!',13,10
    db '16-bit kernel at segment 0x0840.',13,10
    db 'Type PMODE to switch to 32-bit.',13,10,0
readme_size equ $ - readme_code