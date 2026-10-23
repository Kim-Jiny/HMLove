"""스토어용 마케팅 이미지 합성 (Pillow).

사용:  python3 design/store/compose.py
입력:  design/store/raw/ios/*.png      (iOS 시뮬레이터 원본, 1206x2622)
       design/store/raw/android/*.png  (Android 기기 원본, 1080x2340)
출력:  design/store/out/
         ios_1206x2622/  ios_1179x2556/   (App Store, iPhone 6.3" / 6.1")
         android_1080x1920/               (Google Play 휴대전화)
         play/feature_graphic_1024x500.png, play/icon_512.png
         appstore/icon_1024.png
         appstore_art/  헤더(3840x1646, 5244x2950) · 검색결과(1920x1280, 3840x2560)

문구는 SLIDES 만 바꾸면 된다. 폰트는 앱에 번들된 Pretendard 를 쓴다.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
APP = os.path.abspath(os.path.join(ROOT, '..', '..'))
RAW = os.path.join(ROOT, 'raw')
OUT = os.path.join(ROOT, 'out')
FONT_BOLD = os.path.join(APP, 'assets/fonts/Pretendard-Bold.otf')
FONT_MED = os.path.join(APP, 'assets/fonts/Pretendard-Medium.otf')

INK = (74, 59, 82)
ROSE = (236, 95, 142)
BG1 = (255, 214, 228)  # #FFD6E4
BG2 = (230, 223, 255)  # #E6DFFF
SHADOW = (243, 204, 217)

# (원본 파일, 제목 두 줄)
SLIDES = [
    ('1_home', ['둘만의 D-day와', '오늘의 기분을 한눈에']),
    ('2_chat', ['실시간 대화와', '사진 공유까지']),
    ('3_feed', ['일기처럼 남기는', '우리의 하루']),
    ('4_calendar', ['기념일과 데이트 일정을', '함께 관리해요']),
    ('5_question', ['매일 새로운 질문으로', '더 가까워져요']),
    ('6_letter', ['마음을 담은 편지를', '원하는 날 전해요']),
    ('7_fortune', ['오늘의 커플 운세로', '하루를 시작해요']),
    ('8_wishlist', ['함께 하고 싶은 것들을', '위시리스트에']),
]


def gradient(size, c1=BG1, c2=BG2):
    w, h = size
    # 대각선 그라데이션 (작은 크기에서 계산 후 확대해 빠르게)
    small = Image.new('RGB', (64, 64))
    px = small.load()
    for y in range(64):
        for x in range(64):
            t = (x + y) / 126
            px[x, y] = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
    return small.resize((w, h), Image.BICUBIC)


def heart_pts(cx, cy, r):
    pts = []
    for i in range(0, 360, 3):
        t = math.radians(i)
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((cx + x * r / 16, cy + y * r / 16))
    return pts


def draw_heart(d, cx, cy, r, fill, outline=INK, w=8):
    pts = heart_pts(cx, cy, r)
    d.polygon(pts, fill=fill)
    d.line(pts + [pts[0]], fill=outline, width=w, joint='curve')


def draw_sparkle(d, x, y, r, fill=(255, 255, 255)):
    d.polygon([(x, y - r), (x + r * .28, y - r * .28), (x + r, y), (x + r * .28, y + r * .28),
               (x, y + r), (x - r * .28, y + r * .28), (x - r, y), (x - r * .28, y - r * .28)], fill=fill)


def rounded_mask(size, radius, ss=3):
    w, h = size
    m = Image.new('L', (w * ss, h * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * ss - 1, h * ss - 1], radius * ss, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def phone(canvas, shot, x, y, width, radius_ratio=0.085, border=None):
    """스크린샷을 둥근 모서리 + 잉크 윤곽선 + 찍힌 그림자로 캔버스에 붙인다. 아래로 넘치면 잘린다."""
    border = border or max(6, width // 110)
    h = int(shot.height * width / shot.width)
    shot = shot.resize((width, h), Image.LANCZOS)
    r = int(width * radius_ratio)
    # 그림자
    sh = Image.new('RGBA', (width + border * 2, h + border * 2), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([0, 0, width + border * 2 - 1, h + border * 2 - 1], r + border, fill=SHADOW + (255,))
    canvas.paste(sh, (x - border, y - border + int(width * 0.02)), sh)
    # 윤곽선
    ol = Image.new('RGBA', (width + border * 2, h + border * 2), (0, 0, 0, 0))
    ImageDraw.Draw(ol).rounded_rectangle([0, 0, width + border * 2 - 1, h + border * 2 - 1], r + border, fill=INK + (255,))
    canvas.paste(ol, (x - border, y - border), ol)
    # 화면
    canvas.paste(shot.convert('RGB'), (x, y), rounded_mask((width, h), r))


def app_icon(size):
    ic = Image.open(os.path.join(APP, 'appIcon.png')).convert('RGB').resize((size, size), Image.LANCZOS)
    return ic, rounded_mask((size, size), int(size * 0.224))


def text_w(d, s, font):
    b = d.textbbox((0, 0), s, font=font)
    return b[2] - b[0]


def compose(shot, title, size, top_frac, shot_w_frac, brand=True):
    # brand=False 면 앱 아이콘 줄을 빼고 제목을 맨 위부터 둔다(세로 공간이 적은 Android 16:9 용)
    W, H = size
    canvas = gradient(size).convert('RGBA')
    d = ImageDraw.Draw(canvas)

    # 장식 (제목 오른쪽 여백에만)
    draw_sparkle(d, int(W * .90), int(H * .045), int(W * .03))
    if brand:
        draw_sparkle(d, int(W * .79), int(H * .085), int(W * .018))
    draw_heart(d, int(W * .90), int(H * .125), int(W * .052), (255, 160, 190), w=max(5, W // 200))

    pad = int(W * .08)
    y = int(H * .035)
    if brand:
        ic, m = app_icon(int(W * .105))
        canvas.paste(ic, (pad, y), m)
        f_brand = ImageFont.truetype(FONT_BOLD, int(W * .052))
        d.text((pad + ic.width + int(W * .025), y + ic.height // 2), '우리연애', font=f_brand, fill=ROSE, anchor='lm')
        y += ic.height + int(H * .022)

    f_title = ImageFont.truetype(FONT_BOLD, int(W * .080))
    lh = int(W * .080 * 1.28)
    for i, line in enumerate(title):
        d.text((pad, y + i * lh), line, font=f_title, fill=INK)

    sw = int(W * shot_w_frac)
    phone(canvas, shot, (W - sw) // 2, int(H * top_frac), sw)
    return canvas.convert('RGB')


def crop_android(img):
    img = img.copy()
    # 삼성 '엣지 패널' 손잡이(오른쪽 가장자리 회색 막대)가 캡처에 찍혀 있어, 바로 옆 열로 덮는다.
    w = img.width
    strip = img.crop((w - 36, 480, w - 18, 920))
    img.paste(strip, (w - 18, 480))
    # 상태바(시계/아이콘)와 3버튼 내비게이션 바는 스토어 이미지에서 제외
    return img.crop((0, 100, img.width, img.height - 144))


def main():
    os.makedirs(OUT, exist_ok=True)
    jobs = [
        # (출력 폴더, 캔버스, 원본 폴더, 크롭 함수, 스크린샷 시작 위치 비율, 스크린샷 폭 비율)
        ('ios_1206x2622', (1206, 2622), 'ios', lambda i: i, 0.215, 0.78, True),
        ('ios_1179x2556', (1179, 2556), 'ios', lambda i: i, 0.215, 0.78, True),
        ('android_1080x1920', (1080, 1920), 'android', crop_android, 0.20, 0.74, False),
    ]
    for folder, size, src, crop, top, wf, brand in jobs:
        od = os.path.join(OUT, folder)
        os.makedirs(od, exist_ok=True)
        for idx, (name, title) in enumerate(SLIDES, 1):
            shot = crop(Image.open(os.path.join(RAW, src, name + '.png')).convert('RGB'))
            img = compose(shot, title, size, top, wf, brand)
            assert img.size == size, (img.size, size)
            img.save(os.path.join(od, f'{idx:02d}_{name.split("_", 1)[1]}.png'), optimize=True)
        print('wrote', folder, len(SLIDES))

    # --- Google Play 그래픽 이미지 1024x500
    play = os.path.join(OUT, 'play')
    os.makedirs(play, exist_ok=True)
    W, H = 1024, 500
    fg = gradient((W, H)).convert('RGBA')
    d = ImageDraw.Draw(fg)
    draw_sparkle(d, 60, 70, 20); draw_sparkle(d, 560, 440, 16)
    draw_heart(d, 520, 90, 26, (255, 160, 190), w=5)
    ic, m = app_icon(150)
    fg.paste(ic, (70, 110), m)
    d.text((70, 290), '우리연애', font=ImageFont.truetype(FONT_BOLD, 84), fill=INK)
    d.text((74, 392), '둘만의 이야기를 기록하는 커플 앱', font=ImageFont.truetype(FONT_MED, 30), fill=(122, 116, 128))
    s1 = crop_android(Image.open(os.path.join(RAW, 'android', '1_home.png')).convert('RGB'))
    s2 = crop_android(Image.open(os.path.join(RAW, 'android', '2_chat.png')).convert('RGB'))
    phone(fg, s2, 700, 120, 250, border=5)
    phone(fg, s1, 560, 70, 250, border=5)
    fg.convert('RGB').save(os.path.join(play, 'feature_graphic_1024x500.png'), optimize=True)

    # --- App Store 상품 페이지 아트: 헤더 / 검색결과 이미지 (가로형)
    art = os.path.join(OUT, 'appstore_art')
    os.makedirs(art, exist_ok=True)
    shots = {n: Image.open(os.path.join(RAW, 'ios', n + '.png')).convert('RGB')
             for n in ('1_home', '2_chat', '4_calendar', '3_feed')}

    def wide(size, phones, text_x=0.07, title_color=INK):
        W, H = size
        cv = gradient(size).convert('RGBA')
        d = ImageDraw.Draw(cv)
        # 장식
        draw_sparkle(d, int(W * .40), int(H * .12), int(min(W * .02, H * .05)))
        draw_sparkle(d, int(W * .95), int(H * .10), int(min(W * .015, H * .04)))
        draw_heart(d, int(W * .415), int(H * .84), int(min(W * .022, H * .06)), (255, 160, 190), w=max(5, W // 500))
        # 텍스트 블록 (세로 중앙)
        base = min(W * .075, H * .17)
        icon_s = int(base * 1.25)
        f_title = ImageFont.truetype(FONT_BOLD, int(base))
        f_tag = ImageFont.truetype(FONT_MED, int(base * .26))
        f_tag2 = ImageFont.truetype(FONT_MED, int(base * .20))
        gap = int(base * .18)
        total = icon_s + gap + int(base * 1.15) + gap // 2 + int(base * .26 * 1.5) + int(base * .20 * 1.6)
        y = (H - total) // 2
        x = int(W * text_x)
        ic, m = app_icon(icon_s)
        cv.paste(ic, (x, y), m)
        y += icon_s + gap
        d.text((x, y), '우리연애', font=f_title, fill=title_color)
        y += int(base * 1.15) + gap // 2
        d.text((x, y), '둘만의 이야기를 기록하는 커플 앱', font=f_tag, fill=(122, 116, 128))
        y += int(base * .26 * 1.5)
        d.text((x, y), 'D-day · 일기 · 채팅 · 편지 · 위시리스트', font=f_tag2, fill=ROSE)
        # 폰들 (뒤에서 앞으로 그리므로 가운데를 마지막에)
        for name, xf, yf, wf in phones:
            phone(cv, shots[name], int(W * xf), int(H * yf), int(W * wf))
        return cv.convert('RGB')

    header_3840 = wide((3840, 1646), [('4_calendar', .455, .14, .18), ('3_feed', .785, .14, .18), ('1_home', .62, .03, .18)])
    assert header_3840.size == (3840, 1646)
    header_3840.save(os.path.join(art, 'header_3840x1646.png'), optimize=True)
    header_5244 = wide((5244, 2950), [('4_calendar', .45, .24, .19), ('3_feed', .78, .24, .19), ('1_home', .615, .07, .19)], text_x=.07)
    assert header_5244.size == (5244, 2950)
    header_5244.save(os.path.join(art, 'header_5244x2950.png'), optimize=True)

    search_3840 = wide((3840, 2560), [('2_chat', .74, .07, .25), ('1_home', .50, .19, .25)], text_x=.07)
    assert search_3840.size == (3840, 2560)
    search_3840.save(os.path.join(art, 'search_3840x2560.png'), optimize=True)
    search_3840.resize((1920, 1280), Image.LANCZOS).save(os.path.join(art, 'search_1920x1280.png'), optimize=True)
    print('wrote appstore_art')

    # --- 아이콘 (Play 512 / App Store 1024)
    master = Image.open(os.path.join(APP, 'appIcon.png')).convert('RGB')
    master.resize((512, 512), Image.LANCZOS).save(os.path.join(play, 'icon_512.png'), optimize=True)
    ap = os.path.join(OUT, 'appstore')
    os.makedirs(ap, exist_ok=True)
    master.save(os.path.join(ap, 'icon_1024.png'), optimize=True)
    print('done ->', OUT)


if __name__ == '__main__':
    main()
