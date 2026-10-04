import re, subprocess, os, sys, pycdlib, math
from io import BytesIO

N='/home/user/Doubao/chats/38444125548724482/NexOS'
KDIR=N+'/nexdos'

# 1. GB2312 conversion: db '中文' -> db '\xb6\xd6\xce\xc4'
# 逐行处理, 覆盖一行内所有 '...' 引号段(多段字符串如 db 'A',13,10,'B'), 跳过注释行
src=open(f'{KDIR}/kernel.asm',encoding='utf-8').read()
def convseg(m):
    s=m.group(1)
    if not any(ord(c)>=128 for c in s):
        return m.group(0)
    out=[]; asc=[]
    def flush():
        if asc:
            out.append("'"+''.join(asc)+"'"); asc.clear()
    for c in s:
        if ord(c)<128:
            asc.append(c)
        else:
            flush()
            b=c.encode('gb2312')
            out.append('0x%02X,0x%02X'%(b[0],b[1]))
    flush()
    return ','.join(out)
lines=[]
for line in src.split('\n'):
    if line.strip().startswith(';'):
        lines.append(line)
        continue
    lines.append(re.sub(r"'([^']*)'", convseg, line))
src2='\n'.join(lines)
open(f'{KDIR}/kernel_gb.asm','w',encoding='utf-8').write(src2)

# 2. assemble (LIVE=1 或 --live 构建无需安装版)
import sys as _sys
LIVE = ('--live' in _sys.argv) or (os.environ.get('LIVE')=='1')
NASM=['nasm','-f','bin']
if LIVE: NASM.append('-DLIVE')
r=subprocess.run(NASM+['-o',f'{KDIR}/kernel.bin',f'{KDIR}/kernel_gb.asm'],capture_output=True,text=True,cwd=KDIR)
if r.returncode!=0:
    print("NASM ERROR:\n"+r.stderr); sys.exit(1)
kern=open(f'{KDIR}/kernel.bin','rb').read()
print(f"kernel: {len(kern)} bytes")

# 3. pad kernel to 12KB so font sits at fixed 0xB400
kern=kern.ljust(12288,b'\x00')
open(f'{KDIR}/kernel_pad.bin','wb').write(kern)

# 4. bootimg = boot(2048) + kernel(12288) + font + data(TAOHUA 4096 + WALL 65536)
boot=open(f'{KDIR}/boot.bin','rb').read()
font=open(f'{KDIR}/Fonts/font16.fnt','rb').read()
data_taohua=open(f'{KDIR}/data/TAOHUA.TXT','rb').read().ljust(4096,b'\x00')
data_wall=open(f'{KDIR}/data/WALL.BIN','rb').read().ljust(65536,b'\x00')
data=data_taohua+data_wall
bootimg=boot+kern+font+data
font_phys=0x7C00+0x800+12288
data_phys=font_phys+len(font)
wall_phys=data_phys+len(data_taohua)
print(f"font at physical 0x{font_phys:X} (segment 0x{font_phys>>4:X})")
print(f"TAOHUA at physical 0x{data_phys:X} (segment 0x{data_phys>>4:X})")
print(f"WALL at physical 0x{wall_phys:X} (segment 0x{wall_phys>>4:X}), WALL {len(data_wall)}B")
print(f"bootimg: {len(bootimg)} bytes")

# 5. ISO (noemul)
stl=math.ceil(len(bootimg)/2048)
iso=pycdlib.PyCdlib()
iso.new(interchange_level=3, joliet=True)
iso.add_fp(BytesIO(bootimg), len(bootimg), '/BOOT.BIN;1')
iso.add_eltorito('/BOOT.BIN;1', media_name='noemul', platform_id=0, boot_info_table=True)
out = f'{N}/build/nexos_live.iso' if LIVE else f'{N}/build/nexos.iso'
iso.write(out)
iso.close()
print(f"ISO: {out} {os.path.getsize(out)}B, sectors_to_load={stl}, LIVE={LIVE}")
