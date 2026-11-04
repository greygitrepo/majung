"""마중 런처 아이콘 PNG 만들기 (Android 7 이하용 mipmap + Play 스토어 512px).

Android 8+ 는 벡터 적응형 아이콘(res/drawable/ic_launcher_foreground.xml)을 쓴다.
도형을 바꾸면 그 XML 과 이 파일을 같이 고친다.

    python3 -I tools/launcher_icon.py      # Pillow 필요
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / 'app/android/app/src/main/res'
BG = (62, 44, 79)        # 밤하늘 보라 #3E2C4F
AMBER = (246, 178, 74)   # 등불 #F6B24A
GLOW = (255, 226, 166)   # 안쪽 불빛 #FFE2A6
CREAM = (243, 217, 177)  # 손잡이·뚜껑 #F3D9B1
SS = 4  # 슈퍼샘플링 배율
SCALE, PX0, PY0 = 0.8, 54, 56  # XML 의 <group> 과 같은 축소


def full_icon(px):
    """108dp 적응형 아이콘 전체 캔버스를 px 크기로 그린다 (밤의 등불)."""
    s = px * SS
    k = s / 108

    def pt(x, y):
        return ((PX0 + (x - PX0) * SCALE) * k, (PY0 + (y - PY0) * SCALE) * k)

    def box(x0, y0, x1, y1):
        a, b = pt(x0, y0), pt(x1, y1)
        return [a[0], a[1], b[0], b[1]]

    def ln(w):
        return max(1, round(w * SCALE * k))

    im = Image.new('RGBA', (s, s), BG + (255,))
    for r, alpha in ((30, 0.18), (22, 0.22)):  # 불빛 번짐
        layer = Image.new('RGBA', (s, s), (0, 0, 0, 0))
        ImageDraw.Draw(layer).ellipse(box(54 - r, 58 - r, 54 + r, 58 + r), fill=AMBER + (round(255 * alpha),))
        im = Image.alpha_composite(im, layer)
    d = ImageDraw.Draw(im)
    # 손잡이: 2차 베지어 (46,31)-(54,19)-(62,31)
    curve = [pt((1 - t) ** 2 * 46 + 2 * (1 - t) * t * 54 + t * t * 62,
                (1 - t) ** 2 * 31 + 2 * (1 - t) * t * 19 + t * t * 31) for t in [i / 40 for i in range(41)]]
    d.line(curve, fill=CREAM, width=ln(3), joint='curve')
    for x, y in (curve[0], curve[-1]):
        r = ln(3) / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=CREAM)
    d.rounded_rectangle(box(44, 30, 64, 37), radius=3.5 * SCALE * k, fill=CREAM)
    d.rounded_rectangle(box(36, 36, 72, 78), radius=18 * SCALE * k, fill=AMBER)
    d.ellipse(box(44, 41, 64, 69), fill=GLOW)
    d.rounded_rectangle(box(45, 76, 63, 82), radius=3 * SCALE * k, fill=CREAM)
    d.line([pt(54, 82), pt(54, 89)], fill=CREAM, width=ln(3))
    x, y = pt(54, 89)
    r = ln(3) / 2
    d.ellipse([x - r, y - r, x + r, y + r], fill=CREAM)
    return im.convert('RGB').resize((px, px), Image.LANCZOS)


def visible(px):
    """런처가 보여주는 가운데 72dp 영역만 잘라 px 크기로."""
    big = full_icon(px * 108 // 72 + 1)
    w = big.size[0]
    c = w * 18 // 108
    return big.crop((c, c, w - c, w - c)).resize((px, px), Image.LANCZOS)


def round_mask(im):
    m = Image.new('L', (im.size[0] * SS, im.size[1] * SS), 0)
    ImageDraw.Draw(m).ellipse([0, 0, m.size[0] - 1, m.size[1] - 1], fill=255)
    m = m.resize(im.size, Image.LANCZOS)
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.paste(im, (0, 0), m)
    return out


def main():
    for name, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        round_mask(visible(px)).save(RES / f'mipmap-{name}/ic_launcher.png', optimize=True)
    # Play 스토어: 512x512 정사각형, 모서리는 Play 가 둥글게 처리
    out = ROOT / 'docs/store/icon-512.png'
    out.parent.mkdir(parents=True, exist_ok=True)
    visible(512).save(out, optimize=True)


if __name__ == '__main__':
    main()
