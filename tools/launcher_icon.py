"""마중 런처 아이콘 PNG 만들기 (Android 적응형·구형 mipmap, Play 스토어 512px, iOS).

원본: tools/icon/majung-icon.png (정사각형, 모서리까지 그림이 찬 1254px).
아이콘을 바꾸려면 이 파일만 바꾸고 다시 실행한다.

    python3 -I tools/launcher_icon.py      # Pillow 필요

- Android 8+: 적응형 아이콘. 바탕은 values/ic_launcher_colors.xml 의 크림색,
  전경은 drawable-*dpi/ic_launcher_foreground.png (원본을 108dp 중 ART_DP 크기로 가운데에).
  런처는 가운데 72dp 를 원·둥근 사각형 등으로 잘라 보여 주므로, 그림이 72dp 보다 조금 크게 둔다.
- 테마 아이콘(Android 13+): drawable-*dpi/ic_launcher_monochrome.png 는 "마중" 글자 모양만.
- Android 7 이하: mipmap-*/ic_launcher.png (둥근 사각형).
- Play 스토어: docs/store/icon-512.png (정사각형, 모서리는 Play 가 처리).
- iOS: AppIcon.appiconset (투명 없이 정사각형).
- 앱 첫 화면 제목 옆 마크: app/assets/icon/app-mark.png (MARK_DP, 1x~4x 해상도별, 둥근 사각형).
"""
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'tools/icon/majung-icon.png'
RES = ROOT / 'app/android/app/src/main/res'
IOS = ROOT / 'app/ios/Runner/Assets.xcassets/AppIcon.appiconset'
ART_DP = 74      # 108dp 전경 캔버스 안에서 그림이 차지하는 크기 (보이는 영역 72dp 보다 조금 크게)
MONO_DP = 50     # 테마 아이콘 글자 너비 (안전 영역 66dp 안)
DENSITY = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
SS = 4           # 마스크 슈퍼샘플링 배율
MARK_DP = 40     # 첫 화면 제목 옆 마크 크기 (app/lib/ui/widgets.dart AppMark 와 같게)
MARK = ROOT / 'app/assets/icon'


def source():
    return Image.open(SRC).convert('RGB')


def rounded(im, radius_frac=0.2):
    """둥근 사각형 밖을 투명하게."""
    w, h = im.size
    m = Image.new('L', (w * SS, h * SS), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], radius=w * SS * radius_frac, fill=255)
    out = im.convert('RGBA')
    out.putalpha(m.resize((w, h), Image.LANCZOS))
    return out


def foreground(px):
    """108dp 전경 캔버스(px×px). 가운데에 원본을 ART_DP 크기로."""
    art = round(px * ART_DP / 108)
    canvas = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    o = (px - art) // 2
    canvas.paste(source().resize((art, art), Image.LANCZOS).convert('RGBA'), (o, o))
    return canvas


def text_silhouette():
    """원본에서 짙은 남색 "마중" 글자만 흰색 실루엣으로 (알파 = 어두운 정도)."""
    im = source()
    w, h = im.size
    top = im.crop((0, 0, w, int(h * 0.56)))  # 글자는 위쪽 절반, 아래 그림 그림자는 빼기
    r, g, b = top.split()
    gray = top.convert('L')
    # 남색: 어둡고 파란 기가 있는 픽셀
    dark = gray.point(lambda v: 255 if v < 70 else (0 if v > 140 else round((140 - v) * 255 / 70)))
    bluish = ImageChops.subtract(b, r).point(lambda v: 255 if v > 8 else 0).filter(ImageFilter.MaxFilter(5))
    alpha = ImageChops.multiply(dark, bluish)
    box = alpha.point(lambda v: 255 if v > 128 else 0).getbbox()
    alpha = alpha.crop(box)
    sil = Image.new('RGBA', alpha.size, (255, 255, 255, 0))
    sil.putalpha(alpha)
    return sil


def monochrome(px):
    sil = text_silhouette()
    tw = round(px * MONO_DP / 108)
    th = round(sil.size[1] * tw / sil.size[0])
    canvas = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    canvas.paste(sil.resize((tw, th), Image.LANCZOS), ((px - tw) // 2, (px - th) // 2))
    return canvas


def main():
    for name, k in DENSITY.items():
        d = RES / f'drawable-{name}'
        d.mkdir(exist_ok=True)
        foreground(round(108 * k)).save(d / 'ic_launcher_foreground.png', optimize=True)
        monochrome(round(108 * k)).save(d / 'ic_launcher_monochrome.png', optimize=True)
        legacy = round(48 * k)
        rounded(source().resize((legacy, legacy), Image.LANCZOS)).save(
            RES / f'mipmap-{name}/ic_launcher.png', optimize=True)

    store = ROOT / 'docs/store/icon-512.png'
    store.parent.mkdir(parents=True, exist_ok=True)
    source().resize((512, 512), Image.LANCZOS).save(store, optimize=True)

    # Flutter 해상도별 에셋: app-mark.png(1x), 2.0x/, 3.0x/, 4.0x/ (기기에 맞는 것만 읽는다)
    for k in (1, 2, 3, 4):
        d = MARK if k == 1 else MARK / f'{k}.0x'
        d.mkdir(parents=True, exist_ok=True)
        px = MARK_DP * k
        rounded(source().resize((px, px), Image.LANCZOS), radius_frac=0.22).save(d / 'app-mark.png', optimize=True)

    if IOS.exists():
        for img in json.loads((IOS / 'Contents.json').read_text())['images']:
            pt = float(img['size'].split('x')[0])
            px = round(pt * int(img['scale'][0]))
            source().resize((px, px), Image.LANCZOS).save(IOS / img['filename'], optimize=True)


if __name__ == '__main__':
    main()
