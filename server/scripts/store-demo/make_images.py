"""스토어 스크린샷용 데모 이미지 생성 (Pillow). 사용: python3 make_images.py <출력폴더>"""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else 'demo_images'
os.makedirs(OUT, exist_ok=True)
S = 900
INK = (74, 59, 82)

def grad(c1, c2, size=S):
    im = Image.new('RGB', (size, size))
    px = im.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size)
            px[x, y] = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
    return im

def heart(d, cx, cy, r, fill, outline=INK, w=8):
    pts = []
    for i in range(0, 360, 4):
        t = math.radians(i)
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2*t) - 2 * math.cos(3*t) - math.cos(4*t))
        pts.append((cx + x * r / 16, cy + y * r / 16))
    d.polygon(pts, fill=fill)
    d.line(pts + [pts[0]], fill=outline, width=w, joint='curve')

def cloud(d, x, y, s):
    for dx, dy, r in [(0, 0, 50), (55, -20, 62), (115, 0, 48), (60, 18, 46)]:
        d.ellipse([x+dx*s-r*s, y+dy*s-r*s, x+dx*s+r*s, y+dy*s+r*s], fill=(255, 255, 255))

def sparkle(d, x, y, r, fill=(255, 255, 255)):
    d.polygon([(x, y-r), (x+r*0.28, y-r*0.28), (x+r, y), (x+r*0.28, y+r*0.28), (x, y+r), (x-r*0.28, y+r*0.28), (x-r, y), (x-r*0.28, y-r*0.28)], fill=fill)

def finish(im, name):
    im = im.filter(ImageFilter.SMOOTH)
    im.save(os.path.join(OUT, name), quality=92)

# 1) 피크닉
im = grad((255, 226, 236), (214, 236, 255)); d = ImageDraw.Draw(im)
d.ellipse([650, 90, 810, 250], fill=(255, 226, 140), outline=INK, width=8)
cloud(d, 140, 190, 1.1); cloud(d, 470, 130, 0.8)
d.ellipse([-200, 560, 700, 1300], fill=(190, 236, 205), outline=INK, width=8)
d.ellipse([300, 620, 1200, 1400], fill=(170, 226, 195), outline=INK, width=8)
d.polygon([(250, 640), (650, 640), (720, 780), (180, 780)], fill=(255, 190, 205), outline=INK)
d.line([(250, 640), (650, 640), (720, 780), (180, 780), (250, 640)], fill=INK, width=8)
for i, c in enumerate([(255, 255, 255), (255, 190, 205)] * 3):
    pass
d.ellipse([360, 690, 440, 750], fill=(255, 226, 140), outline=INK, width=6)
heart(d, 540, 700, 36, (236, 95, 142), w=6); heart(d, 330, 400, 50, (255, 160, 190), w=7)
finish(im, 'feed_picnic.jpg')

# 2) 카페
im = grad((255, 236, 214), (255, 214, 228)); d = ImageDraw.Draw(im)
d.ellipse([220, 640, 700, 760], fill=(255, 255, 255), outline=INK, width=8)
d.rounded_rectangle([260, 380, 660, 690], 70, fill=(255, 250, 244), outline=INK, width=9)
d.ellipse([650, 440, 790, 580], outline=INK, width=24)
d.rounded_rectangle([290, 400, 630, 470], 40, fill=(190, 140, 110))
heart(d, 460, 560, 62, (236, 95, 142), w=8)
for x, y in [(380, 330), (460, 290), (540, 330)]:
    d.arc([x-30, y-60, x+30, y+30], 200, 340, fill=INK, width=9)
sparkle(d, 170, 220, 38); sparkle(d, 760, 250, 28); sparkle(d, 140, 700, 24)
finish(im, 'feed_cafe.jpg')

# 3) 벚꽃
im = grad((226, 226, 255), (255, 214, 232)); d = ImageDraw.Draw(im)
d.rounded_rectangle([420, 420, 480, 900], 20, fill=(142, 108, 98), outline=INK, width=8)
for cx, cy, r in [(450, 330, 170), (300, 380, 130), (610, 390, 140), (450, 230, 110)]:
    d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(255, 200, 222), outline=INK, width=8)
import random; random.seed(3)
for _ in range(26):
    x, y = random.randint(60, 840), random.randint(120, 840)
    d.ellipse([x-12, y-9, x+12, y+9], fill=(255, 235, 244), outline=INK, width=3)
sparkle(d, 120, 160, 30); sparkle(d, 790, 200, 34)
finish(im, 'feed_sakura.jpg')

# 4) 케이크
im = grad((255, 244, 214), (255, 222, 236)); d = ImageDraw.Draw(im)
d.ellipse([160, 650, 740, 780], fill=(255, 255, 255), outline=INK, width=8)
d.rounded_rectangle([210, 470, 690, 700], 40, fill=(255, 214, 226), outline=INK, width=9)
d.rounded_rectangle([260, 330, 640, 500], 40, fill=(255, 244, 232), outline=INK, width=9)
for x in range(250, 650, 80):
    d.ellipse([x, 460, x+60, 540], fill=(255, 255, 255), outline=INK, width=5)
d.rectangle([440, 230, 460, 330], fill=(167, 139, 250), outline=INK, width=5)
d.ellipse([430, 170, 470, 240], fill=(255, 190, 90), outline=INK, width=5)
heart(d, 330, 585, 28, (236, 95, 142), w=5); heart(d, 570, 585, 28, (236, 95, 142), w=5)
sparkle(d, 140, 200, 30); sparkle(d, 770, 180, 26)
finish(im, 'feed_cake.jpg')

# 5) 채팅 사진 (노을)
im = grad((255, 200, 160), (200, 170, 235)); d = ImageDraw.Draw(im)
d.ellipse([300, 380, 600, 680], fill=(255, 236, 160), outline=INK, width=8)
d.rectangle([0, 600, S, S], fill=(120, 110, 190))
for y in range(640, 900, 40):
    d.line([(100, y), (800, y)], fill=(160, 150, 225), width=6)
heart(d, 450, 800, 50, (255, 150, 180), w=7)
finish(im, 'chat_sunset.jpg')

# 낙서(두들): 흰 배경 + 선
def doodle(name, kind):
    im = Image.new('RGB', (S, S), (255, 255, 255)); d = ImageDraw.Draw(im)
    if kind == 1:
        heart(d, 450, 420, 230, (255, 150, 180), outline=(236, 95, 142), w=22)
        d.arc([300, 560, 600, 760], 20, 160, fill=INK, width=18)
        for x, y in [(250, 250), (650, 260), (200, 600), (700, 620)]:
            sparkle(d, x, y, 46, (250, 200, 80))
    else:
        d.ellipse([260, 260, 640, 640], fill=(255, 226, 140), outline=INK, width=20)
        d.arc([340, 360, 440, 440], 200, 340, fill=INK, width=20); d.arc([460, 360, 560, 440], 200, 340, fill=INK, width=20)
        d.pieslice([360, 450, 540, 580], 0, 180, fill=(230, 110, 130), outline=INK, width=16)
        heart(d, 700, 200, 70, (255, 150, 180), outline=(236, 95, 142), w=14)
    im.save(os.path.join(OUT, name))
doodle('doodle_1.png', 1); doodle('doodle_2.png', 2)
print('images ->', OUT, sorted(os.listdir(OUT)))
