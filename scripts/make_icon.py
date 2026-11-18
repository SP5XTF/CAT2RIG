# Generuje Resources/AppIcon.icns i docs/icon.png:  python3 scripts/make_icon.py  (wymaga: pip install pillow)
from PIL import Image, ImageDraw, ImageFont, ImageFilter
S=4; N=1024*S
def s(v): return int(v*S)
img=Image.new("RGBA",(N,N),(0,0,0,0))

# tło: zaokrąglony kwadrat z pionowym gradientem (siatka ikon macOS: 824 px, promień ~185)
grad=Image.new("RGBA",(N,N))
gd=ImageDraw.Draw(grad)
top=(9,26,52); bot=(28,82,150)
for y in range(N):
    t=y/N
    gd.line([(0,y),(N,y)],fill=tuple(int(top[i]+(bot[i]-top[i])*t) for i in range(3))+(255,))
mask=Image.new("L",(N,N),0)
ImageDraw.Draw(mask).rounded_rectangle([s(100),s(100),s(924),s(924)],radius=s(185),fill=255)
img.paste(grad,(0,0),mask)
d=ImageDraw.Draw(img)

# fale radiowe wokół wierzchołka anteny
cx,cy=512,262
for i,(r,a) in enumerate([(95,255),(165,200),(235,140)]):
    w=s(24)
    box=[s(cx-r),s(cy-r),s(cx+r),s(cy+r)]
    col=(255,176,32,a)
    d.arc(box,start=-38,end=38,fill=col,width=w)
    d.arc(box,start=142,end=218,fill=col,width=w)

# maszt anteny
d.rounded_rectangle([s(500),s(262),s(524),s(600)],radius=s(12),fill=(240,244,250,255))
d.ellipse([s(cx-30),s(cy-30),s(cx+30),s(cy+30)],fill=(255,255,255,255))

# radio (transceiver)
shadow=Image.new("RGBA",(N,N),(0,0,0,0))
ImageDraw.Draw(shadow).rounded_rectangle([s(205),s(600),s(819),s(835)],radius=s(44),fill=(0,0,0,110))
shadow=shadow.filter(ImageFilter.GaussianBlur(s(14)))
img.alpha_composite(shadow)
d=ImageDraw.Draw(img)
d.rounded_rectangle([s(200),s(585),s(824),s(820)],radius=s(44),fill=(214,221,230,255))
d.rounded_rectangle([s(200),s(585),s(824),s(800)],radius=s(44),fill=(236,240,245,255))
# wyświetlacz
d.rounded_rectangle([s(240),s(625),s(610),s(735)],radius=s(16),fill=(22,40,30,255))
d.rounded_rectangle([s(250),s(635),s(600),s(725)],radius=s(12),fill=(120,230,160,255))
import os
FONTS=["/System/Library/Fonts/SFNSMono.ttf","/System/Library/Fonts/Menlo.ttc",
       "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"]
font=ImageFont.truetype(next(f for f in FONTS if os.path.exists(f)),s(70))
d.text((s(425),s(681)),"14.074",font=font,fill=(16,60,36,255),anchor="mm")
# przyciski
for i in range(4):
    x=250+i*92
    d.rounded_rectangle([s(x),s(752),s(x+72),s(778)],radius=s(8),fill=(150,160,175,255))
# gałka strojenia
kx,ky,kr=718,700,78
d.ellipse([s(kx-kr),s(ky-kr),s(kx+kr),s(ky+kr)],fill=(44,50,60,255))
d.ellipse([s(kx-kr+12),s(ky-kr+12),s(kx+kr-12),s(ky+kr-12)],fill=(62,70,84,255))
d.ellipse([s(kx+18),s(ky-48),s(kx+40),s(ky-26)],fill=(255,176,32,255))

out=img.resize((1024,1024),Image.LANCZOS)
root=os.path.join(os.path.dirname(os.path.abspath(__file__)),"..")
out.save(os.path.join(root,"docs/icon.png"))
out.save(os.path.join(root,"Resources/AppIcon-1024.png"))
out.save(os.path.join(root,"Resources/AppIcon.icns"),
         sizes=[(16,16),(32,32),(64,64),(128,128),(256,256),(512,512),(1024,1024)])
print("OK: Resources/AppIcon.icns, docs/icon.png")
