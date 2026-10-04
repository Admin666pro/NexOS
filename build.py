#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
NexOS 构建脚本
所有中间产物统一写入 build/，源码目录保持干净。
"""

import re, subprocess, os, sys, math
from io import BytesIO
import pycdlib

ROOT  = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(ROOT, 'build')
os.makedirs(BUILD, exist_ok=True)

def S(name): return os.path.join(ROOT, name)   # 源文件路径
def B(name): return os.path.join(BUILD, name)  # 构建产物路径

def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT)
    if r.returncode != 0:
        print(f"{os.path.basename(cmd[0]).upper()} ERROR:\n{r.stderr}")
        sys.exit(1)
    return r

# ---------- 0. boot.asm -> build/boot.bin（补到 2048） ----------
run(['nasm', '-f', 'bin', '-o', B('boot.bin'), S('boot.asm')])
boot = open(B('boot.bin'), 'rb').read().ljust(2048, b'\x00')
print(f"boot: {len(boot)} bytes")

# ---------- 1. kernel.asm 中文字符串转 GB2312 -> build/kernel_gb.asm ----------
src = open(S('kernel.asm'), encoding='utf-8').read()

def convseg(m):
    s = m.group(1)
    if not any(ord(c) >= 128 for c in s):
        return m.group(0)
    out, asc = [], []
    def flush():
        if asc:
            out.append("'" + ''.join(asc) + "'")
            asc.clear()
    for c in s:
        if ord(c) < 128:
            asc.append(c)
        else:
            flush()
            b = c.encode('gb2312')
            out.append('0x%02X,0x%02X' % (b[0], b[1]))
    flush()
    return ','.join(out)

lines = []
for line in src.split('\n'):
    if line.strip().startswith(';'):
        lines.append(line)
    else:
        lines.append(re.sub(r"'([^']*)'", convseg, line))
open(B('kernel_gb.asm'), 'w', encoding='utf-8').write('\n'.join(lines))

# ---------- 1.5 hdboot.asm -> build/hdboot.bin ----------
run(['nasm', '-f', 'bin', '-o', B('hdboot.bin'), S('hdboot.asm')])
print(f"hdboot: {os.path.getsize(B('hdboot.bin'))} bytes")

# ---------- 2. 汇编 kernel_gb.asm -> build/kernel.bin ----------
# kernel.asm 里 `incbin 'hdboot.bin'` 现在位于 build/，
# 所以用 -I build/ 让 nasm 的 incbin 能按相对名找到它。
LIVE = ('--live' in sys.argv) or (os.environ.get('LIVE') == '1')
nasm = ['nasm', '-f', 'bin', '-I' + BUILD + os.sep]
if LIVE:
    nasm.append('-DLIVE')
run(nasm + ['-o', B('kernel.bin'), B('kernel_gb.asm')])
kern = open(B('kernel.bin'), 'rb').read()
print(f"kernel: {len(kern)} bytes")

# ---------- 3. kernel 补齐到 12KB ----------
kern_pad = kern.ljust(12288, b'\x00')
open(B('kernel_pad.bin'), 'wb').write(kern_pad)

# ---------- 4. 组合 bootimg ----------
font        = open(S('Fonts/font16.fnt'), 'rb').read()
data_taohua = open(S('data/TAOHUA.TXT'),  'rb').read().ljust(4096,  b'\x00')
data_wall   = open(S('data/WALL.BIN'),    'rb').read().ljust(65536, b'\x00')
data        = data_taohua + data_wall
bootimg     = boot + kern_pad + font + data

font_phys = 0x7C00 + 0x800 + 12288
data_phys = font_phys + len(font)
wall_phys = data_phys + len(data_taohua)
print(f"font   @ 0x{font_phys:X} (seg 0x{font_phys>>4:X})")
print(f"TAOHUA @ 0x{data_phys:X} (seg 0x{data_phys>>4:X})")
print(f"WALL   @ 0x{wall_phys:X} (seg 0x{wall_phys>>4:X}), {len(data_wall)}B")
print(f"bootimg: {len(bootimg)} bytes")

# ---------- 5. 生成 ISO ----------
stl = math.ceil(len(bootimg) / 2048)
iso = pycdlib.PyCdlib()
iso.new(interchange_level=3, joliet=True)
iso.add_fp(BytesIO(bootimg), len(bootimg), '/BOOT.BIN;1')
iso.add_eltorito('/BOOT.BIN;1', media_name='noemul', platform_id=0,
                 boot_info_table=True)
out = B('nexos_live.iso' if LIVE else 'nexos.iso')
iso.write(out)
iso.close()
print(f"ISO: {out} {os.path.getsize(out)}B, sectors_to_load={stl}, LIVE={LIVE}")
