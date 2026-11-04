"""시도·시군구 이름 정규화와 지역 목록(app/assets/data/regions.json).

- 시도는 2026-07-01 이후 16개, 짧은 이름으로 쓴다 (docs/policy/data.md §2).
- 시군구 이름·코드는 국토교통부 전국 법정동(2026-07-29) 기준. 대표 좌표는
  data/curated/derived/sigungu-centroids.csv (pipeline/extract.py centroids 로 SGIS 경계에서 계산).
"""
from __future__ import annotations

import csv
import math
import re
from dataclasses import dataclass, field
from pathlib import Path

SIDO_ORDER = ["서울", "부산", "대구", "인천", "전남광주", "대전", "울산", "세종",
              "경기", "강원", "충북", "충남", "전북", "경북", "경남", "제주"]

_SIDO_ALIASES = {
    "서울": ["서울특별시", "서울시", "서울"],
    "부산": ["부산광역시", "부산시", "부산"],
    "대구": ["대구광역시", "대구시", "대구"],
    "인천": ["인천광역시", "인천시", "인천"],
    # 2026-07-01 광주광역시 + 전라남도 → 전남광주통합특별시 (법률 제21446호). 원본에 "광주전남…" 오기도 있다.
    "전남광주": ["전남광주통합특별시", "광주전남통합특별시", "전남광주", "광주광역시", "전라남도", "광주", "전남"],
    "대전": ["대전광역시", "대전시", "대전"],
    "울산": ["울산광역시", "울산시", "울산"],
    "세종": ["세종특별자치시", "세종시", "세종"],
    "경기": ["경기도", "경기"],
    "강원": ["강원특별자치도", "강원도", "강원"],
    "충북": ["충청북도", "충북"],
    "충남": ["충청남도", "충남"],
    "전북": ["전북특별자치도", "전라북도", "전북"],
    "경북": ["경상북도", "경북"],
    "경남": ["경상남도", "경남"],
    "제주": ["제주특별자치도", "제주도", "제주"],
}
_SHORT_ALIASES = set(SIDO_ORDER) | {"광주", "전남"}
_ALIAS_LIST = sorted(((a, s) for s, names in _SIDO_ALIASES.items() for a in names), key=lambda x: -len(x[0]))

# SGIS 2025-2Q 시도 코드 → 지금 시도 (광주 24·전남 36 → 전남광주)
SGIS_SIDO = {"11": "서울", "21": "부산", "22": "대구", "23": "인천", "24": "전남광주", "25": "대전",
             "26": "울산", "29": "세종", "31": "경기", "32": "강원", "33": "충북", "34": "충남",
             "35": "전북", "36": "전남광주", "37": "경북", "38": "경남", "39": "제주"}

# 시군구 별칭 (원본 이름 → 앱 이름). 지금은 없음.
# 인천 서구 → "서해구": 국토교통부 법정동(2026-07-29, 시행 2026-06-30 코드 28275)·HIRA(2026-09 주소 433건)·
# 서해구청 누리집이 모두 "서해구"를 쓴다. 재검증(verify-legal-clinic-20261104.md B1)은 설치법 원문만 보고 "서구"로
# 판정했으나 운영 자료 3곳과 다르므로 "서해구"를 쓴다 (2026-11-04 결정, data/research/regions-incheon-seohae.md).
SIGUNGU_ALIASES: dict[tuple[str, str], str] = {}

# 없어지거나 나뉜 시군구 → 지금 후보 (원본 주소에 옛 이름이 남아 있을 때 읍면동으로 가린다)
SPLITS = {
    ("인천", "중구"): ["제물포구", "영종구"],
    ("인천", "동구"): ["제물포구"],
    ("인천", "서구"): ["서해구", "검단구"],
    ("경기", "화성시"): ["화성시 만세구", "화성시 효행구", "화성시 병점구", "화성시 동탄구"],
}

# 지역번호가 시도 하나로 정해지는 곳만 (경기는 광명·과천 등이 02라 제외).
AREA_CODES = {"서울": "02", "부산": "051", "대구": "053", "인천": "032", "대전": "042", "울산": "052",
              "세종": "044", "강원": "033", "충북": "043", "충남": "041", "전북": "063",
              "경북": "054", "경남": "055", "제주": "064"}
_GWANGJU_GU = {"동구", "서구", "남구", "북구", "광산구"}


def normalize_sido(text: str | None) -> tuple[str | None, str]:
    """주소 앞부분의 시도 이름 → (짧은 이름, 나머지). '충청남도홍성군 …' 처럼 붙어 있어도 된다."""
    t = re.sub(r"\s+", " ", text or "").strip()
    for alias, short in _ALIAS_LIST:
        if t.startswith(alias):
            rest = t[len(alias):]
            if rest and not rest.startswith(" ") and alias in _SHORT_ALIASES:
                # "제주시 …" 같은 걸 시도로 오인하지 않도록 짧은 별칭은 띄어쓰기 뒤에만 인정
                continue
            return short, rest.strip()
    return None, t


# 시도와 지역번호가 다른 시군구 (생활권 번호). 예: 경북 경산시는 대구 053, 충남 계룡시는 대전 042.
_AREA_EXCEPTIONS = {("대구", "군위군"): "054", ("경북", "경산시"): "053", ("충남", "계룡시"): "042"}


def area_code_for(sido: str | None, sigungu: str | None) -> str | None:
    """지역번호가 하나로 정해질 때만 돌려준다. 경기(02·031·032 섞임)와 시군구를 모르는 전남광주는 None."""
    if (sido, sigungu) in _AREA_EXCEPTIONS:
        return _AREA_EXCEPTIONS[(sido, sigungu)]
    if sido == "전남광주":
        if not sigungu:
            return None
        return "062" if sigungu in _GWANGJU_GU else "061"
    return AREA_CODES.get(sido or "")


def molit_name(name: str, parents: set[str]) -> str:
    """'화성시만세구' → '화성시 만세구' (부모 시가 목록에 있을 때만)."""
    m = re.fullmatch(r"(.+?시)(.+구)", name)
    if m and m.group(1) in parents:
        return f"{m.group(1)} {m.group(2)}"
    return name


@dataclass
class Region:
    code: str
    sido: str
    sigungu: str
    lat: float
    lng: float
    approximate: str | None = None
    bbox: tuple[float, float, float, float] | None = None  # 경계 상자 (min_lat, min_lng, max_lat, max_lng)


@dataclass
class Catalog:
    regions: list[Region]
    dongs: dict[tuple[str, str], set[str]] = field(default_factory=dict)  # (시도, 시군구) → 읍면동 이름

    def __post_init__(self):
        self.by_key = {(r.sido, r.sigungu): r for r in self.regions}
        self.by_sido: dict[str, list[Region]] = {}
        for r in self.regions:
            self.by_sido.setdefault(r.sido, []).append(r)

    def has(self, sido: str, sigungu: str) -> bool:
        return (sido, sigungu) in self.by_key

    def sido_bbox(self, sido: str, margin: float = 0.05) -> tuple[float, float, float, float] | None:
        """시도의 경계 상자(시군구 경계 상자를 합침) + 여유. 경계 상자가 없으면 대표점 상자 + 0.3°."""
        rs = self.by_sido.get(sido)
        if not rs:
            return None
        if all(r.bbox for r in rs):
            return (min(r.bbox[0] for r in rs) - margin, min(r.bbox[1] for r in rs) - margin,
                    max(r.bbox[2] for r in rs) + margin, max(r.bbox[3] for r in rs) + margin)
        return (min(r.lat for r in rs) - 0.3, min(r.lng for r in rs) - 0.3,
                max(r.lat for r in rs) + 0.3, max(r.lng for r in rs) + 0.3)

    def nearest(self, lat: float, lng: float, among: list[tuple[str, str]]) -> str | None:
        best, best_d = None, math.inf
        for key in among:
            r = self.by_key.get(key)
            if r is None:
                continue
            d = (r.lat - lat) ** 2 + ((r.lng - lng) * math.cos(math.radians(lat))) ** 2
            if d < best_d:
                best, best_d = r.sigungu, d
        return best

    def resolve_sigungu(self, sido: str, rest: str, dong_hints: list[str] = (),
                        lat: float | None = None, lng: float | None = None) -> tuple[str | None, str | None]:
        """시도를 뺀 주소 → (시군구, 경고). 옛 이름·나뉜 구는 읍면동으로, 안 되면 좌표로 가린다."""
        if sido == "세종":
            return ("세종시", None) if self.has("세종", "세종시") else (None, "세종시 지역 없음")
        toks = rest.replace(",", " ").split()
        if not toks:
            return None, "주소에 시군구 없음"
        t1 = toks[0]
        m = re.fullmatch(r"(.+?시)(.+구)", t1)  # '화성시만세구' 처럼 붙여 쓴 것
        if m:
            toks = [m.group(1), m.group(2)] + toks[1:]
            t1 = toks[0]
        cands = []
        if len(toks) > 1:
            cands.append(f"{t1} {toks[1]}")
        cands.append(t1)
        for raw in cands:
            c = SIGUNGU_ALIASES.get((sido, raw), raw)
            if c != raw and self.has(sido, c):
                return c, None  # 새 이름(예: 서해구)으로 적혀 있으면 확실하다
            if (sido, c) in SPLITS:
                choice = self._split(sido, c, toks[1:], dong_hints, lat, lng)
                if choice[0]:
                    return choice
            if self.has(sido, c):
                return c, None
        return None, f"시군구를 알 수 없음: {sido} {' '.join(toks[:2])}"

    def _split(self, sido, old, more_tokens, dong_hints, lat, lng):
        targets = SPLITS[(sido, old)]
        if len(targets) == 1:
            return targets[0], None
        names = [t for t in list(dong_hints) + list(more_tokens[:2]) if t]
        for name in names:
            hits = [t for t in targets if name in self.dongs.get((sido, t), set())]
            if len(hits) == 1:
                return hits[0], None
        if lat is not None and lng is not None:
            near = self.nearest(lat, lng, [(sido, t) for t in targets])
            if near:
                return near, f"옛 시군구 '{old}' → 좌표로 가장 가까운 '{near}' (읍면동으로 못 가림)"
        return None, f"옛 시군구 '{old}' — 새 구를 정하지 못함"


def read_molit(path: Path) -> list[list[str]]:
    with Path(path).open(encoding="utf-8-sig", newline="") as fh:
        return list(csv.reader(fh))[1:]


def read_commented_csv(path: Path) -> list[dict]:
    """'#' 로 시작하는 줄(출처 설명)은 건너뛴다."""
    with Path(path).open(encoding="utf-8", newline="") as fh:
        lines = [ln for ln in fh if not ln.startswith("#")]
    return list(csv.DictReader(lines))


def build_catalog(molit_rows: list[list[str]], centroid_rows: list[dict]) -> tuple[Catalog, list[str]]:
    """법정동 목록(이름·코드) + 대표 좌표 → Catalog. 경고 목록도 돌려준다."""
    warnings: list[str] = []
    cent = {}
    for c in centroid_rows:
        sido = c["sido"]
        name = SIGUNGU_ALIASES.get((sido, c["sigungu"]), c["sigungu"])
        cent[(sido, name)] = c

    sgg = []  # (code5, sido, raw name)
    dong_rows = []
    for r in molit_rows:
        code, sido_long, sgg_name, emd = r[0], r[1], r[2], r[3]
        sido, _ = normalize_sido(sido_long)
        if sido is None:
            warnings.append(f"법정동: 알 수 없는 시도 {sido_long}")
            continue
        if sgg_name and not emd:
            sgg.append((code[:5], sido, sgg_name))
        elif sgg_name and emd:
            dong_rows.append((sido, sgg_name, emd))
    parents = {n for _, _, n in sgg}
    with_children = set()
    for code, sido, name in sgg:
        full = molit_name(name, parents)
        if " " in full:
            with_children.add((sido, full.split(" ")[0]))

    regions = []
    for code, sido, name in sgg:
        full = molit_name(name, parents)
        if (sido, full) in with_children:
            continue  # 일반구가 있는 시는 구 단위로만
        full = SIGUNGU_ALIASES.get((sido, full), full)
        c = cent.get((sido, full))
        if c is None:
            warnings.append(f"지역 대표 좌표 없음: {sido} {full} ({code}) — 지역 목록에서 뺌")
            continue
        approx = c.get("approximate") or None
        box = None
        if c.get("min_lat"):
            box = (float(c["min_lat"]), float(c["min_lng"]), float(c["max_lat"]), float(c["max_lng"]))
        regions.append(Region(code, sido, full, round(float(c["lat"]), 5), round(float(c["lng"]), 5), approx, box))
        if approx:
            warnings.append(f"지역 대표 좌표 근사값: {sido} {full} — {approx}")
    regions.sort(key=lambda r: r.code)
    codes = [r.code for r in regions]
    if len(codes) != len(set(codes)):
        warnings.append("지역 코드 중복")

    dongs: dict[tuple[str, str], set[str]] = {}
    for sido, sgg_name, emd in dong_rows:
        full = SIGUNGU_ALIASES.get((sido, molit_name(sgg_name, parents)), molit_name(sgg_name, parents))
        dongs.setdefault((sido, full), set()).add(emd)
    return Catalog(regions, dongs), warnings


def regions_json(cat: Catalog) -> list[dict]:
    return [{"code": r.code, "sido": r.sido, "sigungu": r.sigungu, "lat": r.lat, "lng": r.lng} for r in cat.regions]
