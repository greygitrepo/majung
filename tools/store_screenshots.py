"""README 스크린샷(docs/screenshots)에서 Play 스토어용 휴대전화 스크린샷을 만든다.

Play 규격(answer/9866151, 2026-11-06 확인): 24비트 PNG(알파 없음), 긴 쪽이 짧은 쪽의 2배 이하,
추천 노출 조건 9:16·1080×1920 이상·4장 이상. 스크린샷은 9:16 에뮬레이터 화면에서 찍는다
(integration_test/screenshots_test.dart 맨 위 명령 + `adb shell wm size 1080x1920`).

사용: python3 -I tools/store_screenshots.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs/screenshots"
OUT = ROOT / "docs/store/screenshots"

# 스토어에 보이는 순서. 앞의 것일수록 많이 보인다.
ORDER = [
    "shot-1-home",        # 첫 화면: 밥·잠자리·아플 때
    "shot-3-meal-list",   # 가까운 곳 목록, 전화 버튼
    "shot-4-detail",      # 상세: 전화·길찾기·운영 시간
    "shot-8-emergency",   # 급할 때 전화
    "shot-7-busan-map",   # 지도
    "shot-5-clinic",      # 아플 때: 의료급여 안내
    "shot-6-busan-list",  # 확인 안 된 정보는 확인 필요로 표시
]


def check(img: Image.Image, name: str) -> None:
    w, h = img.size
    if max(w, h) > 2 * min(w, h):
        raise ValueError(f"{name}: {w}×{h}는 긴 쪽이 짧은 쪽의 2배를 넘습니다")
    if min(w, h) < 1080:
        raise ValueError(f"{name}: {w}×{h}는 1080px보다 작습니다")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("phone-*.png"):
        old.unlink()
    for i, name in enumerate(ORDER, start=1):
        img = Image.open(SRC / f"{name}.png").convert("RGB")
        check(img, name)
        dest = OUT / f"phone-{i}-{name.removeprefix('shot-').split('-', 1)[1]}.png"
        img.save(dest, "PNG", optimize=True)
        print(dest.relative_to(ROOT), img.size)


if __name__ == "__main__":
    main()
