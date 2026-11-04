"""고운돋움(Gowun Dodum) 글꼴을 앱에 넣을 만큼 줄인다 (7.2MB → 약 1.2MB).

남기는 글자: 영문·숫자·기본 기호, KS X 1001 한글 2,350자, 앱 문구(app_ko.arb)와
시설·지역 데이터(facilities.json, regions.json)에 나오는 모든 글자. 빠진 글자는 휴대폰 기본 글꼴로 보인다.
시설 데이터에 드문 글자가 새로 들어오면 다시 돌린다.

원본: https://github.com/google/fonts/tree/main/ofl/gowundodum (SIL OFL 1.1, 예약 글꼴 이름 없음)

    python3 -I tools/subset_font.py <원본 GowunDodum-Regular.ttf>     # fontTools 필요
"""
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'app/assets/fonts/GowunDodum-Subset.ttf'


def wanted_chars():
    chars = {chr(c) for c in range(0x20, 0x7F)}
    for hi in range(0xB0, 0xC9):  # KS X 1001 한글 영역
        for lo in range(0xA1, 0xFF):
            try:
                chars.add(bytes([hi, lo]).decode('euc-kr'))
            except UnicodeDecodeError:
                pass
    chars |= set('·…~–—‘’“”「」『』()[]•○●※→←↑↓℃°%')
    for p in ('app/lib/l10n/app_ko.arb', 'app/assets/data/facilities.json', 'app/assets/data/regions.json'):
        chars |= set((ROOT / p).read_text(encoding='utf-8'))
    return ''.join(sorted(c for c in chars if c.isprintable()))


def main():
    src = sys.argv[1]
    with tempfile.NamedTemporaryFile('w', suffix='.txt', encoding='utf-8', delete=False) as f:
        f.write(wanted_chars())
    subprocess.run([sys.executable, '-I', '-m', 'fontTools.subset', src, f'--text-file={f.name}',
                    f'--output-file={OUT}', "--layout-features=*", '--no-hinting', '--desubroutinize'], check=True)
    print(OUT, OUT.stat().st_size)


if __name__ == '__main__':
    main()
