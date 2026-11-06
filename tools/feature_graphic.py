"""Play 스토어 그래픽 이미지(1024×500)를 만든다 → docs/store/feature-graphic.png

Play 규격(answer/9866151, 2026-11-06 확인): 1024×500, JPEG 또는 24비트 PNG(알파 없음).
흰색·검정·짙은 회색 배경은 피하고, 가장자리에는 중요한 것을 두지 않는다.
아이콘은 런처 아이콘과 같은 원본(tools/icon/majung-icon.png), 색은 앱 테마(lib/ui/theme.dart).

사용: python3 -I tools/feature_graphic.py [--font 경로]
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ICON = ROOT / "tools/icon/majung-icon.png"
OUT = ROOT / "docs/store/feature-graphic.png"
FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"
FONT_KR_INDEX = 1  # NotoSansCJK-Bold.ttc 안의 KR 글꼴 (fc-list로 확인)

W, H = 1024, 500
SAND = (246, 233, 220)       # AppColors.sand
INK = (58, 42, 31)           # AppColors.ink
INK_SOFT = (107, 84, 68)     # AppColors.inkSoft
TERRACOTTA = (154, 69, 36)   # AppColors.terracottaDeep

LINES = [
    ("무료 급식소 · 쉼터", 50, INK),
    ("무료 진료소", 50, INK),
    ("가까운 곳부터 찾아요", 36, TERRACOTTA),
    ("가입 없이 · 무료 · 인터넷 없이도", 26, INK_SOFT),
]


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *img.size), radius=radius, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img.convert("RGBA"), (0, 0), mask)
    return out


def build(font_path: str = FONT, out: Path = OUT) -> Image.Image:
    canvas = Image.new("RGB", (W, H), SAND)
    icon_size = 340
    icon = rounded(Image.open(ICON).convert("RGB").resize((icon_size, icon_size), Image.LANCZOS), 56)
    left = 80
    canvas.paste(icon, (left, (H - icon_size) // 2), icon)

    draw = ImageDraw.Draw(canvas)
    x = left + icon_size + 56
    fonts = [ImageFont.truetype(font_path, size, index=FONT_KR_INDEX) for _, size, _ in LINES]
    gaps = [14, 30, 22, 0]
    heights = [f.getbbox(t)[3] - f.getbbox(t)[1] for (t, _, _), f in zip(LINES, fonts)]
    total = sum(heights) + sum(gaps)
    y = (H - total) // 2
    for (text, _, color), font, h, gap in zip(LINES, fonts, heights, gaps):
        top = font.getbbox(text)[1]
        draw.text((x, y - top), text, font=font, fill=color)
        y += h + gap
    right_edge = max(x + font.getlength(t) for (t, _, _), font in zip(LINES, fonts))
    if right_edge > W - 48:
        raise ValueError(f"글자가 오른쪽 가장자리에 너무 가깝습니다: {right_edge:.0f}px")

    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out, "PNG", optimize=True)
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--font", default=FONT)
    args = parser.parse_args()
    build(args.font)
    print(f"만들었습니다: {OUT}")


if __name__ == "__main__":
    main()
