"""스토어 등록정보(docs/store/listing-ko.md)의 글자 수와 금지 표현을 확인한다.

Play 한도(answer/9866151, 2026-11-06 확인): 앱 이름 30자, 간단한 설명 80자, 자세한 설명 4000자.
금지 표현은 docs/policy/play-store.md 5절(과장·정부 표방 금지)을 따른다.

사용: python3 -I tools/check_listing.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LISTING = ROOT / "docs/store/listing-ko.md"

LIMITS = {"앱 이름": 30, "간단한 설명": 80, "자세한 설명": 4000}

# 사실이 아니거나 공식 앱처럼 보일 수 있는 말. "정부나 지자체가 만든 앱이 아니에요"처럼
# 부정하는 문장은 허용하려고, 금지어마다 허용 문맥을 둔다.
FORBIDDEN = {
    "실시간": None,
    "모든 ": None,
    "공식": None,
    "정확한": None,
    "최고": None,
    "1위": None,
    "정부": r"정부나 지자체가 만든 앱이 아니에요",
}

_EMOJI = re.compile("[\U0001F300-\U0001FAFF☀-➿]")


def sections(md: str) -> dict[str, str]:
    """'## 이름 (...)' 다음의 첫 ``` 코드 블록을 그 항목의 값으로 본다."""
    out: dict[str, str] = {}
    for m in re.finditer(r"^## ([^\n(]+?)\s*(?:\([^)]*\))?\n+```\n(.*?)\n```", md, re.M | re.S):
        out[m.group(1).strip()] = m.group(2)
    return out


def problems(md: str) -> list[str]:
    found = sections(md)
    errs: list[str] = []
    for name, limit in LIMITS.items():
        text = found.get(name)
        if text is None:
            errs.append(f"{name}: 항목이 없습니다")
            continue
        if len(text) > limit:
            errs.append(f"{name}: {len(text)}자 (한도 {limit}자)")
        for word, allowed in FORBIDDEN.items():
            cleaned = re.sub(allowed, "", text) if allowed else text
            if word in cleaned:
                errs.append(f"{name}: 쓰지 않기로 한 표현 '{word.strip()}'")
    short = found.get("간단한 설명", "")
    if _EMOJI.search(short):
        errs.append("간단한 설명: 이모지·기호는 쓰지 않습니다")
    return errs


def main() -> int:
    md = LISTING.read_text(encoding="utf-8")
    for name, text in sections(md).items():
        if name in LIMITS:
            print(f"{name}: {len(text)}자 / {LIMITS[name]}자")
    errs = problems(md)
    for e in errs:
        print("문제:", e)
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
