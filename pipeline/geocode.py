"""주소 → 좌표 (빌드 준비 단계 전용). 앱과 build.py 는 네트워크를 쓰지 않는다.

    python3 -I pipeline/geocode.py fetch     # 캐시에 없는 주소만 OSM Nominatim 에 묻고 data/curated/geocode-cache.json 에 저장

- 대상: build.py 가 "좌표 없음"으로 모은 공식 주소(SSIS 노숙인시설 등, 약 15곳)뿐.
- Nominatim 사용 정책: 1초에 1번 이하, User-Agent "majung-data-pipeline/1.0" (이메일·개인정보 없음), 결과는 캐시해서 다시 묻지 않음.
- 결과(ODbL)는 좌표 하나만 쓰고 출처(osm-nominatim)를 표시한다. 검증(validate)을 통과한 것만 앱에 넣는다.
"""
from __future__ import annotations

import json
import math
import re
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "data/curated/geocode-cache.json"
USER_AGENT = "majung-data-pipeline/1.0"
ENDPOINT = "https://nominatim.openstreetmap.org/search"
MAX_KM_FROM_SIGUNGU = 10.0
MAX_ROAD_KM = 1.0  # 건물이 아니라 도로 전체가 나왔을 때, 도로가 이보다 길면 위치를 믿지 않는다


def query_for(addr: str, detail: str = "") -> str:
    """'부산광역시 부산진구 가야대로587번길' + '8, 2~3층 (가야동)' → '부산광역시 부산진구 가야대로587번길 8'."""
    addr = re.sub(r"\s+", " ", addr or "").strip()
    m = re.match(r"\s*(\d+(?:-\d+)?)", detail or "")
    return f"{addr} {m.group(1)}" if m else addr


def road_name(query: str) -> str | None:
    """주소에서 도로명('가야대로587번길', '영서로')."""
    for tok in reversed(query.split()):
        if re.search(r"(로|길)$", tok) and not re.fullmatch(r"\d.*", tok):
            return tok
    return None


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def load_cache(path: Path = CACHE) -> dict[str, dict]:
    if not path.exists():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    return {e["query"]: e for e in data["entries"]}


def house_number(query: str) -> str | None:
    m = re.search(r"\s(\d+(?:-\d+)?)$", query)
    return m.group(1) if m else None


def validate(entry: dict | None, sido: str, sigungu: str | None, cat) -> tuple[dict | None, str]:
    """캐시 항목 → (쓸 결과 또는 None, 설명). 결과마다 차례로 검사해서 처음 통과한 것을 쓴다.

    공통: ① 시도 경계 상자 안 ② 시군구 대표점에서 10km 이내 ③ display_name 에 도로명이 있음.
    건물·장소 결과: display_name 에 건물번호가 정확히 있어야 함('369' 를 찾았는데 '369-1' 이면 의심).
    도로 결과(건물을 못 찾음): 짧은 골목길('…길')이고 조각 길이 1km 이하일 때만 '도로 단위' 근사값으로 받는다.
    큰길('…로')은 OSM 이 도로 조각만 돌려주므로 건물이 어디쯤인지 알 수 없어 받지 않는다.
    """
    if entry is None:
        return None, "캐시에 없음 (pipeline/geocode.py fetch 필요)"
    results = entry.get("results") or []
    if not results:
        return None, "검색 결과 없음"
    road = road_name(entry["query"])
    number = house_number(entry["query"])
    box = cat.sido_bbox(sido)
    region = cat.by_key.get((sido, sigungu)) if sigungu else None
    reasons = []
    for r in results:
        lat, lng = float(r["lat"]), float(r["lng"])
        parts = [p.strip() for p in r.get("display_name", "").split(",")]
        if box and not (box[0] <= lat <= box[2] and box[1] <= lng <= box[3]):
            reasons.append("시도 범위 밖")
            continue
        if region is None:
            reasons.append("시군구 대표점 없음")
            continue
        d = haversine_km(lat, lng, region.lat, region.lng)
        if d > MAX_KM_FROM_SIGUNGU:
            reasons.append(f"시군구 대표점에서 {d:.1f}km")
            continue
        if not road or road not in [p.replace(" ", "") for p in parts]:
            reasons.append(f"결과에 도로명 '{road}' 없음")
            continue
        if r.get("category") != "highway":
            if not number or number not in parts:
                reasons.append(f"건물번호 {number} 가 결과({', '.join(parts[:2])})와 다름")
                continue
            return r, f"건물·번지 단위 ({r.get('category')}/{r.get('type')}, 시군구 대표점에서 {d:.1f}km)"
        if not road.endswith("길"):
            reasons.append(f"큰길 '{road}' 의 도로 조각만 나옴 — 건물 위치를 알 수 없음")
            continue
        b = [float(x) for x in r.get("boundingbox") or []]
        if len(b) != 4:
            reasons.append("도로 결과인데 범위 없음")
            continue
        diag = haversine_km(b[0], b[2], b[1], b[3])
        if diag > MAX_ROAD_KM:
            reasons.append(f"골목길 조각이 {diag:.1f}km 로 김")
            continue
        return r, f"도로 단위 근사값 (골목길 '{road}' 길이 약 {diag:.2f}km, 시군구 대표점에서 {d:.1f}km)"
    return None, "; ".join(dict.fromkeys(reasons))


def fetch(queries: list[str], today: str, path: Path = CACHE) -> None:
    import urllib.parse
    import urllib.request
    cache = load_cache(path)
    todo = [q for q in sorted(set(queries)) if q not in cache]
    for i, q in enumerate(todo):
        if i:
            time.sleep(1.1)
        url = ENDPOINT + "?" + urllib.parse.urlencode(
            {"q": q, "format": "jsonv2", "countrycodes": "kr", "limit": 3})
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=20) as resp:
            got = json.load(resp)
        cache[q] = {
            "query": q, "date": today,
            "results": [{"lat": g["lat"], "lng": g["lon"], "display_name": g.get("display_name", ""),
                         "osm_type": g.get("osm_type"), "osm_id": g.get("osm_id"), "category": g.get("category"),
                         "type": g.get("type"), "boundingbox": g.get("boundingbox")} for g in got],
        }
        print(f"{q} → {len(got)}건", file=sys.stderr)
    out = {
        "_설명": ("OSM Nominatim 지오코딩 캐시 (© OpenStreetMap 기여자, ODbL). pipeline/geocode.py fetch 가 만든다. "
                  "build.py 는 이 파일만 읽고 네트워크를 쓰지 않는다. 결과는 pipeline/geocode.validate 로 검증한 것만 쓴다."),
        "user_agent": USER_AGENT,
        "entries": [cache[q] for q in sorted(cache)],
    }
    path.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("what", choices=["fetch"])
    p.add_argument("--today", required=True)
    args = p.parse_args(argv)
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import build
    from datetime import date
    _, _, report = build.build(ROOT, "geocode-prep", date.fromisoformat(args.today))
    fetch(sorted(report.geocode_missing), args.today)
    return 0


if __name__ == "__main__":
    sys.exit(main())
