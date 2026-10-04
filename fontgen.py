from PIL import Image, ImageDraw, ImageFont
FONT='/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc'
OUT='/home/user/Doubao/chats/38444125548724482/NexOS/nexdos/Fonts/font16.fnt'
data=bytearray()
f=ImageFont.truetype(FONT, 16)
# ASCII 0-255, 8x16, 16 bytes each
for c in range(256):
    img=Image.new('L',(8,16),0); d=ImageDraw.Draw(img)
    if 32<=c<127:
        d.text((0,0),chr(c),font=f,fill=255)
    px=img.load()
    for y in range(16):
        b=0
        for x in range(8):
            if px[x,y]>100: b|=1<<(7-x)
        data.append(b)
# GB2312 zones 1-87, 16x16, 32 bytes each
missing=0
for qu in range(1,88):
    for w in range(1,95):
        hi=0xA0+qu; lo=0xA0+w
        try:
            s=bytes([hi,lo]).decode('gb2312')
        except Exception:
            data+=bytes(32); missing+=1; continue
        img=Image.new('L',(16,16),0); d=ImageDraw.Draw(img)
        try:
            d.text((0,0),s,font=f,fill=255)
        except Exception:
            data+=bytes(32); missing+=1; continue
        px=img.load()
        for y in range(16):
            b1=0;b2=0
            for x in range(8):
                if px[x,y]>100: b1|=1<<(7-x)
            for x in range(8,16):
                if px[x,y]>100: b2|=1<<(15-x)
            data.append(b1);data.append(b2)
# pad 到 265824B, 保持 TAOHUA/WALL 物理地址 (0x4C260/0x4D260) 不变
data += bytes(265824 - len(data))
open(OUT,'wb').write(data)
print(f"font16.fnt: {len(data)} bytes, missing={missing}")
