"""GitHub Pages에 올릴 정적 사이트를 만든다.

입력
  docs/privacy-policy.md        → privacy.html (개인정보처리방침)
  app/assets/data/facilities.json → data/facilities.json (앱이 받아가는 시설 데이터)
출력
  build/site/  (기본값, .gitignore 대상)

외부 라이브러리 없이 개인정보처리방침에 쓰는 마크다운 일부만 바꾼다:
제목(#, ##), 문단, 목록(-), 표, **굵게**, `코드`, 주소 자동 링크.
'>' 로 시작하는 줄은 저장소 안 작업 메모라서 사이트에 싣지 않는다.

사용: python3 -I tools/build_site.py [--out DIR]
"""

from __future__ import annotations

import argparse
import html
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
POLICY = ROOT / "docs/privacy-policy.md"
DATA = ROOT / "app/assets/data/facilities.json"

SITE_TITLE = "마중 - 무료급식·쉼터 지도"
CONTACT = "majungdev@gmail.com"

STYLE = """
:root { --bg:#fffdf8; --fg:#1d1b18; --muted:#5b554c; --line:#d9d2c5; --link:#0b57d0; }
@media (prefers-color-scheme: dark) {
  :root { --bg:#171512; --fg:#f3efe7; --muted:#c3bbad; --line:#3d3830; --link:#8ab4f8; }
}
* { box-sizing: border-box; }
body { margin:0; background:var(--bg); color:var(--fg);
  font: 18px/1.7 system-ui, -apple-system, "Noto Sans KR", "Apple SD Gothic Neo", sans-serif; }
main { max-width: 760px; margin: 0 auto; padding: 24px 16px 64px; }
h1 { font-size: 1.6em; line-height: 1.3; }
h2 { font-size: 1.25em; margin-top: 2em; padding-top: .6em; border-top: 1px solid var(--line); }
a { color: var(--link); }
.muted { color: var(--muted); }
.table { overflow-x: auto; }
table { border-collapse: collapse; width: 100%; font-size: .92em; }
th, td { border: 1px solid var(--line); padding: 8px 10px; text-align: left; vertical-align: top; }
code { font-size: .9em; }
"""

_URL = re.compile(r"(?<![\"'=])(https?://[^\s<)]+)")


def inline(text: str) -> str:
    """한 줄 안의 강조·코드·링크. 먼저 HTML을 이스케이프한다."""
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = _URL.sub(r'<a href="\1">\1</a>', out)
    return out


def _is_table_divider(line: str) -> bool:
    return bool(re.fullmatch(r"\|[\s:|-]+\|", line.strip()))


def _cells(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def markdown_to_html(md: str) -> tuple[str, str]:
    """(제목, 본문 HTML)을 돌려준다."""
    lines = md.splitlines()
    title = ""
    parts: list[str] = []
    para: list[str] = []
    items: list[str] = []

    def flush() -> None:
        if para:
            parts.append(f"<p>{inline(' '.join(para))}</p>")
            para.clear()
        if items:
            parts.append("<ul>" + "".join(f"<li>{inline(i)}</li>" for i in items) + "</ul>")
            items.clear()

    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        stripped = line.strip()
        if not stripped:
            flush()
        elif stripped.startswith(">"):
            flush()  # 작업 메모 — 싣지 않음
        elif stripped.startswith("# "):
            flush()
            title = stripped[2:].strip()
        elif stripped.startswith("## "):
            flush()
            parts.append(f"<h2>{inline(stripped[3:].strip())}</h2>")
        elif stripped.startswith("- "):
            if para:
                flush()
            items.append(stripped[2:].strip())
        elif stripped.startswith("|") and i + 1 < len(lines) and _is_table_divider(lines[i + 1]):
            flush()
            head = _cells(stripped)
            rows = []
            i += 2
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(_cells(lines[i]))
                i += 1
            table = "<thead><tr>" + "".join(f"<th>{inline(c)}</th>" for c in head) + "</tr></thead><tbody>"
            table += "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>" for r in rows)
            parts.append(f'<div class="table"><table>{table}</tbody></table></div>')
            continue
        else:
            if items:
                flush()
            para.append(stripped)
        i += 1
    flush()
    if not title:
        raise ValueError("개인정보처리방침에 제목(# ...)이 없습니다")
    return title, "\n".join(parts)


def page(title: str, body: str) -> str:
    return f"""<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<style>{STYLE}</style>
</head>
<body>
<main>
{body}
</main>
</body>
</html>
"""


def check_policy(md: str) -> None:
    """공개하면 안 되는 상태의 문서를 막는다."""
    if "(초안)" in md:
        raise ValueError("개인정보처리방침 제목에 (초안)이 남아 있습니다")
    m = re.search(r"^시행일:\s*(.+)$", md, re.M)
    if not m or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", m.group(1).strip()):
        raise ValueError("개인정보처리방침 시행일이 날짜(YYYY-MM-DD)가 아닙니다")


def check_data(raw: str) -> None:
    """앱이 받아들이지 않을 데이터는 올리지 않는다 (앱도 거부하지만 한 번 더)."""
    data = json.loads(raw)
    if not isinstance(data, dict) or not data.get("version"):
        raise ValueError("시설 데이터에 version이 없습니다")
    if not data.get("facilities"):
        raise ValueError("시설 데이터가 비어 있습니다")


def build(out: Path, policy: Path = POLICY, data: Path = DATA) -> None:
    md = policy.read_text(encoding="utf-8")
    check_policy(md)
    raw = data.read_text(encoding="utf-8")
    check_data(raw)

    if out.exists():
        shutil.rmtree(out)
    (out / "data").mkdir(parents=True)

    title, body = markdown_to_html(md)
    (out / "privacy.html").write_text(page(title, f"<h1>{inline(title)}</h1>\n{body}"), encoding="utf-8")

    index = f"""<h1>{html.escape(SITE_TITLE)}</h1>
<p>무료급식소, 잠잘 곳, 무료 진료소를 한 지도에서 찾는 무료 앱입니다. 회원가입이 없고, 내 위치는 휴대폰 밖으로 보내지 않습니다.</p>
<ul>
<li><a href="privacy.html">개인정보처리방침</a></li>
</ul>
<p class="muted">문의: <a href="mailto:{CONTACT}">{CONTACT}</a></p>"""
    (out / "index.html").write_text(page(SITE_TITLE, index), encoding="utf-8")
    shutil.copyfile(data, out / "data/facilities.json")
    (out / ".nojekyll").write_text("", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=str(ROOT / "build/site"))
    args = parser.parse_args()
    out = Path(args.out)
    build(out)
    print(f"사이트를 만들었습니다: {out}")


if __name__ == "__main__":
    main()
