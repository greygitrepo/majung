"""공공데이터 원본 + 사람이 확인한 보정(data/overrides) → 앱 데이터.

    python3 -I pipeline/build.py --today 2026-11-04 --version 2026-11-04T18:00:00+09:00

출력: app/assets/data/facilities.json, app/assets/data/regions.json, data/build-report.md
표준 라이브러리만 쓴다. 같은 입력·같은 --today/--version 이면 같은 출력이 나온다.
빌드 로직은 현재 시각을 직접 읽지 않는다(--today 로 주입). 검증에 실패한 시설은 넣지 않고 보고서에 남긴다.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import geocode  # noqa: E402
import regions as rg  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
DAYS = {"mon", "tue", "wed", "thu", "fri", "sat", "sun"}
ALL_DAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
CATEGORIES = {"meal", "shelter", "foodbank", "foodmarket", "shower", "laundry", "clinic", "counseling"}
VERIFIED_BY = {"public_data", "official", "phone", "field", "report"}
HUMAN_VERIFIED = {"official", "phone", "field"}
SUBTYPES = {"free_clinic", "health_center", "hospital_support"}
MAX_AGE_DAYS = 365
HIRA_AS_OF = "2026-09-30"
OPTIONAL_KEYS = ("phone", "hours_note", "holiday_policy", "eligibility", "requirements", "source_url",
                 "sigungu", "subtype")
SIZE_LIMIT = 1_500_000


@dataclass
class Report:
    included: list[str] = field(default_factory=list)
    excluded: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    to_verify: list[str] = field(default_factory=list)
    need_coords: list[str] = field(default_factory=list)
    region_notes: list[str] = field(default_factory=list)
    mismatches: list[str] = field(default_factory=list)
    geocoded: list[str] = field(default_factory=list)
    geocode_missing: set = field(default_factory=set)
    drops: Counter = field(default_factory=Counter)
    summary: list[str] = field(default_factory=list)

    def drop(self, reason: str, detail: str | None = None) -> None:
        self.drops[reason] += 1
        if detail:
            self.excluded.append(f"{reason}: {detail}")

    def markdown(self, version: str, today: str) -> str:
        def section(title: str, items: list[str]) -> str:
            body = "\n".join(f"- {i}" for i in items) if items else "- (없음)"
            return f"## {title} ({len(items)})\n\n{body}\n"

        drops = "\n".join(f"| {k} | {v} |" for k, v in sorted(self.drops.items(), key=lambda x: (-x[1], x[0])))
        return "\n".join([
            "# 데이터 빌드 보고서",
            "",
            f"버전: {version} · 빌드 기준일(--today): {today}",
            "",
            "## 요약",
            "",
            *self.summary,
            "",
            "## 뺀 행 — 사유별 개수",
            "",
            "| 사유 | 행 수 |",
            "|---|---|",
            drops or "| (없음) | 0 |",
            "",
            section("좌표 필요 — 공식 좌표가 없어 넣지 못한 곳", self.need_coords),
            section("지오코딩 좌표 (OSM Nominatim, geocoded: true) — 사람 확인 필요", self.geocoded),
            section("출처 불일치 (SSIS ↔ 다른 공식 출처)", self.mismatches),
            section("경고 — 사람이 검토해야 함", self.warnings),
            section("전화 확인 필요", self.to_verify),
            section("지역 목록 메모", self.region_notes),
            section("제외 상세", self.excluded),
            section("포함 (보건소·보건지소 제외)", self.included),
        ])


# ---------- 정규화 ----------

def normalize_phone(raw: str | None) -> str | None:
    """'027775217' → '02-777-5217', '0220691600' → '02-2069-1600'. 형식이 안 맞으면 None (지역번호를 추측하지 않음)."""
    if not raw:
        return None
    d = re.sub(r"\D", "", raw)
    if not d:
        return None
    if re.fullmatch(r"1[5-9]\d{6}", d):
        return f"{d[:4]}-{d[4:]}"
    if d.startswith("02") and len(d) in (9, 10):
        return f"02-{d[2:-4]}-{d[-4:]}"
    if re.fullmatch(r"050\d{8,9}", d):
        return f"{d[:4]}-{d[4:-4]}-{d[-4:]}"
    if re.fullmatch(r"0\d{9,10}", d):
        return f"{d[:3]}-{d[3:-4]}-{d[-4:]}"
    return None


_KNOWN_PREFIX = re.compile(r"0(2|3[1-3]|4[1-4]|5[1-5]|6[1-4]|70|10|50\d|80)")


def clean_phone(raw: str | None, sido: str | None, sigungu: str | None) -> tuple[str | None, str | None, bool]:
    """원본 전화 → (전화 또는 None, 문제 설명, 사람이 확인해야 하는지).

    - 지역번호 + 15xx/16xx 대표번호(예: 02-1666-7995), 02-0…/02-1… 같은 불가능한 국번 → None
    - 지역번호 없는 7~8자리는 시도(전남광주는 시군구)로 지역번호가 하나로 정해질 때만 붙이고 '확인 필요'
    - 시도와 지역번호가 다르면 번호는 두되 '확인 필요'
    """
    d = re.sub(r"\D", "", raw or "")
    if not d:
        return None, "전화번호 없음", True
    if re.fullmatch(r"1[5-9]\d{6}", d):
        return normalize_phone(d), None, False
    m = re.fullmatch(r"(02|0[3-6]\d)(1[5-9]\d{6})", d)
    if m:
        return None, f"지역번호+대표번호 형식 {raw!r} (오기·팩스 의심)", True
    if re.fullmatch(r"[2-9]\d{6,7}", d):
        area = rg.area_code_for(sido, sigungu)
        if area:
            return normalize_phone(area + d), f"지역번호 없음 {raw!r} → {area} 붙임 (추정)", True
        return None, f"지역번호 없음 {raw!r} (지역번호를 하나로 정할 수 없음)", True
    if re.fullmatch(r"02[01]\d+", d):
        return None, f"불가능한 국번 {raw!r}", True
    if not _KNOWN_PREFIX.match(d):
        return None, f"알 수 없는 지역번호 {raw!r}", True
    phone = normalize_phone(d)
    if phone is None:
        return None, f"형식 오류 {raw!r}", True
    area = rg.area_code_for(sido, sigungu)
    prefix = phone.split("-")[0]
    if area and prefix.startswith("0") and len(prefix) <= 3 and prefix not in ("010", "070", "080") and prefix != area:
        return phone, f"지역번호 {prefix} 가 {sido} 지역({area})과 다름 — 운영기관 본부 번호일 수 있음", True
    return phone, None, False


def is_valid_phone(p: str) -> bool:
    d = re.sub(r"[\s\-()]", "", p)
    return bool(
        re.fullmatch(r"1\d{2}", d) or re.fullmatch(r"1[5-9]\d{6}", d) or re.fullmatch(r"0\d{8,11}", d)
    )


def short_address(addr: str) -> str:
    """시도 이름을 짧게, 띄어쓰기 정리. '서울특별시  용산구 …' → '서울 용산구 …'."""
    addr = re.sub(r"\s+", " ", addr).strip()
    addr = re.sub(r"(\S)\(", r"\1 (", addr)
    sido, rest = rg.normalize_sido(addr)
    return f"{sido} {rest}".strip() if sido else addr


def eligibility_text(target: str | None) -> str | None:
    """원문 대상 표기를 낙인 없는 쉬운 말로 (docs/policy/ux-accessibility.md §2)."""
    if not target or not target.strip():
        return None
    parts = [p.strip() for p in re.split(r"[+,/]", target) if p.strip()]
    mapping = {"노숙인": "노숙 중인 분", "노숙자": "노숙 중인 분", "주거취약계층": "집이 불안정한 분", "누구나": "누구나"}
    out = []
    for p in parts:
        v = mapping.get(p) or re.sub(r"노숙(인|자)", "노숙 중인 분", re.sub(r"\s+", " ", p))
        if v not in out:
            out.append(v)
    return ", ".join(out)


_SENIOR = re.compile(r"노인|어르신|[5-9]\d\s*세|경로|노년|독거")
_OPEN_TO_ALL = re.compile(r"노숙|누구나|제한\s*없|모두|전\s*연령")
_CHILD = re.compile(r"아동|청소년|학생|어린이")


def classify_audience(target: str | None) -> str:
    """노인만 대상(경로식당 등, 미리 등록) → senior. 노숙·누구나가 함께 있으면 general (decisions #18)."""
    t = target or ""
    if _SENIOR.search(t) and not _OPEN_TO_ALL.search(t):
        return "senior"
    return "general"


def is_child_only(target: str | None) -> bool:
    t = target or ""
    return bool(_CHILD.search(t)) and not _SENIOR.search(t) and not _OPEN_TO_ALL.search(t) and "성인" not in t


_STOPPED = re.compile(r"중단|휴업|폐업|폐지")


def is_stopped(text: str) -> bool:
    """'임시운영중단', '미운영', '2021년 한시적 사업중단'. 단 '토요일 경로식당 미운영으로 대체식' 은 운영 중."""
    t = (text or "").strip()
    return bool(_STOPPED.search(t)) or t.startswith("미운영") or t == "운영안함"


def parse_date(s: str | None) -> date | None:
    try:
        return datetime.strptime((s or "").strip(), "%Y-%m-%d").date()
    except ValueError:
        return None


def stable_id(prefix: str, *parts: str) -> str:
    h = hashlib.sha1("|".join(parts).encode("utf-8")).hexdigest()[:10]
    return f"{prefix}-{h}"


def _norm(s: str) -> str:
    s = re.sub(r"\(.*?\)", "", s or "")
    return re.sub(r"[\s,·\-\.]", "", s)


def dong_hints(*texts: str) -> list[str]:
    """주소 문자열에서 읍면동 이름 후보 ('(운서동)', '… 남양읍 …')."""
    out = []
    for t in texts:
        for m in re.finditer(r"\(([^)]*)\)", t or ""):
            for part in re.split(r"[,\s]+", m.group(1)):
                if re.search(r"[동읍면가리]$", part):
                    out.append(part)
        for tok in (t or "").split():
            if re.fullmatch(r"\S+[동읍면가]", tok) and not re.search(r"\d", tok):
                out.append(tok)
    return out


# ---------- 검증 (앱 Facility.fromJson 과 같은 규칙 + 데이터 정책) ----------

def validate(f: dict) -> list[str]:
    errors = []
    for key in ("id", "name", "category", "address", "source_id", "last_verified", "sido", "verified_by",
                "cost", "audience"):
        if not isinstance(f.get(key), str) or not f[key].strip():
            errors.append(f"필수 필드 없음: {key}")
    if f.get("category") not in CATEGORIES:
        errors.append(f"알 수 없는 분류: {f.get('category')}")
    if f.get("sido") not in rg.SIDO_ORDER:
        errors.append(f"알 수 없는 시도: {f.get('sido')}")
    if f.get("audience") not in ("general", "senior"):
        errors.append(f"알 수 없는 대상: {f.get('audience')}")
    if f.get("cost") not in ("free", "low_cost"):
        errors.append(f"알 수 없는 비용: {f.get('cost')}")
    if f.get("verified_by") not in VERIFIED_BY:
        errors.append(f"알 수 없는 확인 방법: {f.get('verified_by')}")
    if f.get("category") == "clinic":
        if f.get("subtype") not in SUBTYPES:
            errors.append(f"진료 세부 분류 없음/오류: {f.get('subtype')}")
    elif f.get("subtype") is not None:
        errors.append("subtype 은 clinic 에만")
    lat, lng = f.get("lat"), f.get("lng")
    if not isinstance(lat, (int, float)) or not isinstance(lng, (int, float)):
        errors.append("좌표 없음")
    elif not (33.0 <= lat <= 38.7 and 124.5 <= lng <= 132.0):
        errors.append(f"좌표가 국내 범위 밖: {lat}, {lng}")
    if f.get("phone") and not is_valid_phone(f["phone"]):
        errors.append(f"전화번호 형식 오류: {f['phone']}")
    hours = f.get("hours")
    if not isinstance(hours, list):
        errors.append("hours 는 목록이어야 함")
        hours = []
    if hours and f.get("verified_by") not in HUMAN_VERIFIED:
        errors.append("공공데이터(사람 확인 없음)인데 구조화된 운영시간이 있음 (decisions #16)")
    for rule in hours:
        if not rule.get("days") or not set(rule["days"]) <= DAYS:
            errors.append(f"요일 오류: {rule.get('days')}")
        for k in ("open", "close"):
            if not re.fullmatch(r"([01]?\d|2[0-4]):[0-5]\d", str(rule.get(k, ""))):
                errors.append(f"시간 형식 오류: {rule.get(k)}")
    if f.get("holiday_policy") not in (None, "open", "closed"):
        errors.append(f"공휴일 정책 오류: {f.get('holiday_policy')}")
    if "geocoded" in f and not isinstance(f["geocoded"], bool):
        errors.append("geocoded 는 true/false")
    if parse_date(f.get("last_verified")) is None:
        errors.append(f"날짜 형식 오류: {f.get('last_verified')}")
    return errors


def location_warnings(f: dict, cat: rg.Catalog) -> list[str]:
    """좌표가 그 시도 대략 범위(시군구 대표점 상자 + 0.3°) 안인지, 시군구 이름이 목록에 있는지."""
    out = []
    box = cat.sido_bbox(f["sido"])
    if box and not (box[0] <= f["lat"] <= box[2] and box[1] <= f["lng"] <= box[3]):
        out.append(f"좌표({f['lat']}, {f['lng']})가 {f['sido']} 범위 밖 — 주소·좌표 확인 필요")
    if f.get("sigungu") and not cat.has(f["sido"], f["sigungu"]):
        out.append(f"시군구 '{f['sigungu']}' 가 지역 목록에 없음")
    return out


# ---------- 원본 읽기 ----------

def read_csv(path: Path) -> list[dict]:
    import csv
    raw = Path(path).read_bytes()
    for enc in ("utf-8-sig", "cp949"):
        try:
            text = raw.decode(enc)
        except UnicodeDecodeError:
            continue
        lines = [ln for ln in io.StringIO(text) if not ln.startswith("#")]
        return list(csv.DictReader(lines))
    raise ValueError(f"인코딩을 알 수 없음: {path}")


def raw_date_from_path(path: Path) -> str:
    m = re.search(r"_(\d{4})(\d{2})(\d{2})", str(path))
    if not m:
        raise ValueError(f"원본 폴더 이름에 날짜가 없음: {path}")
    return f"{m.group(1)}-{m.group(2)}-{m.group(3)}"


# ---------- 보정 적용 ----------

SETTABLE = {"name", "address", "lat", "lng", "phone", "hours", "hours_note", "holiday_policy", "eligibility",
            "requirements", "cost", "audience", "verified_by", "last_verified", "source_url", "sigungu"}


def apply_override(f: dict, ov: dict, report: Report, label: str) -> dict:
    f = dict(f)
    if ov.get("id"):
        f["id"] = ov["id"]
    s = ov.get("set", {})
    unknown = set(s) - SETTABLE
    if unknown:
        report.warnings.append(f"{label}: 알 수 없는 보정 필드 {sorted(unknown)} — 무시")
    if s.get("hours") and (s.get("verified_by") not in HUMAN_VERIFIED or not ov.get("sources")):
        report.warnings.append(f"{label}: 근거 없는 운영시간 보정 — 무시")
        s = {k: v for k, v in s.items() if k != "hours"}
    for k, v in s.items():
        if k in SETTABLE:
            f[k] = v
    if "phone" in s and not ov.get("phone_confirmed") and s["phone"]:
        report.to_verify.append(f"{label}: 전화번호 보정 → {s['phone']} ({ov.get('reason', '')})")
    if ov.get("append_note"):
        f["hours_note"] = f"{f['hours_note']} {ov['append_note']}".strip() if f.get("hours_note") else ov["append_note"]
    if ov.get("flag"):
        report.warnings.append(f"{label}: {ov['flag']}")
    return f


# ---------- 급식 ----------

def build_meals(rows: list[dict], overrides: list[dict], cat: rg.Catalog, today: date, report: Report,
                source_id: str = "national-free-meal-std") -> list[dict]:
    cutoff = today - timedelta(days=MAX_AGE_DAYS)
    ov_used = [False] * len(overrides)

    def find_override(sido: str | None, r: dict) -> int | None:
        for i, ov in enumerate(overrides):
            m = ov["match"]
            if m.get("sido") == sido and m.get("name") == (r.get("FCLTY_NM") or "").strip() and \
                    (not m.get("reference_date") or m["reference_date"] == r.get("REFERENCE_DATE")):
                return i
        return None

    def coords(r: dict) -> tuple[float, float] | None:
        try:
            return float(r.get("LATITUDE") or "x"), float(r.get("LONGITUDE") or "x")
        except ValueError:
            return None

    # 1) 보정 제외, 이름·주소·시도
    named = []
    for r in rows:
        name = (r.get("FCLTY_NM") or "").strip()
        addr = (r.get("RDNMADR") or "").strip() or (r.get("LNMADR") or "").strip()
        sido, rest = rg.normalize_sido(addr)
        if sido is None:
            sido, _ = rg.normalize_sido(r.get("INSTT_NM"))
        label = f"[급식] {name} ({addr})"
        oi = find_override(sido, r)
        if oi is not None:
            ov_used[oi] = True
            if overrides[oi].get("exclude"):
                report.drop("보정: 제외", f"{label} — {overrides[oi]['exclude']}")
                continue
        if not name or not addr or sido is None:
            report.drop("이름·주소·시도 없음", label)
            continue
        named.append((sido, rest, addr, name, oi, r))

    # 2) 중복: 시도 + 정규화한 이름 + 주소 (옛 '광주광역시' 행과 '전남광주통합특별시' 행도 같은 곳).
    #    좌표가 있고, 운영 중이고, 기준일이 새로운 행을 남긴다.
    def quality(c):
        r = c[5]
        close = parse_date(r.get("OPER_CLOSE_DATE"))
        ref = parse_date(r.get("REFERENCE_DATE")) or date.min
        return (coords(r) is not None, close is None or close >= today, ref.toordinal())

    def reject(r: dict, label: str) -> tuple[str, str | None] | None:
        close = parse_date(r.get("OPER_CLOSE_DATE"))
        if close is not None and close < today:
            return "운영종료일 지남", None
        ref = parse_date(r.get("REFERENCE_DATE"))
        if ref is None or ref < cutoff:
            return f"기준일이 {MAX_AGE_DAYS}일보다 오래됨(또는 없음)", None
        if coords(r) is None:
            return "좌표 없음", None
        if is_stopped(r.get("MLSV_DATE", "")) or is_stopped(r.get("MLSV_TIME", "")):
            return "미운영·중단 표기", label
        if is_child_only(r.get("MLSV_TRGET")):
            return "아동 전용(지역아동센터 등)", None
        return None

    groups: dict[tuple, list] = defaultdict(list)
    for c in named:
        groups[(c[0], _norm(c[3]), _norm(c[1]))].append(c)
    candidates = []
    for key in sorted(groups):
        group = sorted(groups[key], key=lambda c: (tuple(-int(x) for x in quality(c)),
                                                    json.dumps(c[5], ensure_ascii=False, sort_keys=True)))
        passing = []
        first_reason = None
        for c in group:
            label = f"[급식] {c[3]} ({c[2]})"
            if (c[5].get("OPER_CLOSE_DATE") or "").strip() and parse_date(c[5].get("OPER_CLOSE_DATE")) is None:
                report.warnings.append(f"{label}: 운영종료일 형식 이상 {c[5].get('OPER_CLOSE_DATE')!r} — 무시")
            why = reject(c[5], label)
            if why is None:
                passing.append(c)
            elif first_reason is None:
                first_reason = why
        if not passing:
            report.drop(*first_reason)
            report.drops["중복(같은 시도·이름·주소)"] += len(group) - 1
            continue
        report.drops["중복(같은 시도·이름·주소)"] += len(group) - len(passing)
        # 같은 곳의 여러 일정(예: 요일마다 다른 단체가 배식) → 한 시설로 합치고 일정을 모두 안내
        sido, rest, addr, name, oi, r = passing[0]
        for c in passing[1:]:
            report.drops["같은 곳 여러 일정 → 한 시설로 합침"] += 1
            if oi is None:
                oi = c[4]
        schedules = []
        for c in passing:
            t = " ".join(x for x in [(c[5].get("MLSV_DATE") or "").strip(), (c[5].get("MLSV_TIME") or "").strip()] if x)
            if t and t not in schedules:
                schedules.append(t)
        lat, lng = coords(r)
        candidates.append((sido, rest, addr, name, lat, lng, parse_date(r.get("REFERENCE_DATE")), oi, r, schedules))

    out = []
    for sido, rest, addr, name, lat, lng, ref, oi, r, schedules in candidates:
        sigungu, sg_warn = cat.resolve_sigungu(sido, rest, dong_hints(r.get("LNMADR", ""), r.get("RDNMADR", "")),
                                               lat, lng)
        label = f"[급식] {name} ({short_address(addr)})"
        if sg_warn:
            report.warnings.append(f"{label}: {sg_warn}")
        target = (r.get("MLSV_TRGET") or "").strip()
        phone, issue, check = clean_phone(r.get("PHONE_NUMBER"), sido, sigungu)
        note = " / ".join(schedules)
        f = {
            "id": stable_id("meal", sido, _norm(name), _norm(rest)),
            "name": name,
            "category": "meal",
            "address": short_address(addr),
            "lat": lat,
            "lng": lng,
            "phone": phone,
            "hours": [],
            "hours_note": f"공공데이터 안내: {note}" if note else None,
            "holiday_policy": None,
            "eligibility": eligibility_text(target),
            "requirements": None,
            "cost": "low_cost" if re.search(r"실비|유료", target) else "free",
            "source_id": source_id,
            "last_verified": ref.isoformat(),
            "verified_by": "public_data",
            "sido": sido,
            "sigungu": sigungu,
            "audience": classify_audience(target),
        }
        place = (r.get("MLSV_PLACE") or "").strip()
        if re.search(r"역|광장|공원", place) and _norm(place) not in _norm(addr) and _norm(place) not in _norm(name):
            report.warnings.append(f"{label}: 급식 장소 '{place}' 가 주소와 다를 수 있음 — 지도 위치 확인 필요")
        if oi is not None:
            ov = overrides[oi]
            for k, v in (ov.get("expect_raw") or {}).items():
                if (r.get(k) or "") != v:
                    report.warnings.append(f"{label}: 원본 {k} 가 바뀜 {r.get(k)!r} (보정 때는 {v!r}) — 보정 다시 확인")
            phone_set = "phone" in ov.get("set", {})
            f = apply_override(f, ov, report, label)
            if phone_set:
                issue, check = None, False
        if issue and check:
            report.to_verify.append(f"{label}: {issue}")
        out.append(f)

    for i, ov in enumerate(overrides):
        if not ov_used[i]:
            report.warnings.append(f"[급식] 보정 대상 '{ov['match'].get('name')}' ({ov['match'].get('sido')}) 이 원본에 없음 — 폐지 여부 확인 필요")
    return out


# ---------- 잠자리 (SSIS 노숙인시설) ----------

RAW_TABLES = {
    "ssis-welfare-basic": {"addr": ("시설주소", "시설상세1주소"), "phone": "시설전화번호"},
    "busan-homeless-fac": {"addr": ("도로명주소",), "phone": "전화번호", "lat": "위도", "lng": "경도", "date": "데이터기준일자"},
    "daegu-buk-homeless-fac": {"addr": ("주소",), "phone": "전화번호", "lat": "위도", "lng": "경도", "date": "데이터기준일자"},
    "seoul-heat-shelter": {"addr": ("도로명주소",), "lat": "위도", "lng": "경도"},
}
SSIS_SOURCE = "ssis-fclt-api"
SSIS_DATE = "2026-11-04"


def address_core(addr: str) -> str | None:
    """주소에서 '도로명+건물번호' ('동천로 108번길 14' → '동천로108번길14'). 비교용."""
    t = re.sub(r"\s+", " ", addr or "")
    t = re.sub(r"(로|길)\s+(\d+번?길)", r"\1\2", t)          # '동천로 108번길' → '동천로108번길'
    t = re.sub(r"(길)(\d+(?:-\d+)?)(?=\D|$)", r"\1 \2", t)   # '칠성남로38길22' → '칠성남로38길 22'
    m = re.search(r"([가-힣A-Za-z0-9]+(?:로|길))\s*(\d+(?:-\d+)?)", t)
    return f"{m.group(1)}{m.group(2)}" if m else None


def digits(p: str | None) -> str:
    return re.sub(r"\D", "", p or "")


def ssis_address(row: dict) -> str:
    return re.sub(r"\s+", " ", f"{row['addr']} {row['addr_detail']}").strip()


def compare_sources(label: str, addr: str, phone: str | None, checks: list[dict], report: Report) -> int:
    """SSIS 값과 다른 공식 출처를 비교. 주어진 칸이 모두 같은 출처 수를 돌려주고, 다르면 보고서에 남긴다."""
    agree = 0
    core = address_core(addr)
    for c in checks:
        ok = True
        if c.get("address"):
            if address_core(c["address"]) != core:
                ok = False
                report.mismatches.append(f"{label}: 주소 SSIS '{addr}' ↔ {c['source']} '{c['address']}' → SSIS(2026-11-04, 더 최신) 사용")
        if c.get("address_contains") and c["address_contains"] not in addr:
            ok = False
            report.mismatches.append(f"{label}: 주소 SSIS '{addr}' 에 '{c['address_contains']}' 없음 ({c['source']})")
        if c.get("phone"):
            if digits(c["phone"]) != digits(phone):
                ok = False
                report.mismatches.append(f"{label}: 전화 SSIS {phone} ↔ {c['source']} {c['phone']} → SSIS(2026-11-04, 더 최신) 사용")
        agree += ok
    return agree


def geocoded_coords(query: str, sido: str, sigungu: str | None, geocache: dict, cat: rg.Catalog,
                    report: Report, label: str) -> tuple[float, float] | None:
    entry = geocache.get(query)
    if entry is None:
        report.geocode_missing.add(query)
    hit, why = geocode.validate(entry, sido, sigungu, cat)
    if hit is None:
        report.need_coords.append(f"{label} — 지오코딩 실패/의심: {why} (검색어 '{query}')")
        return None
    report.geocoded.append(f"{label}: {float(hit['lat']):.6f}, {float(hit['lng']):.6f} — {why}; "
                           f"OSM {hit.get('osm_type')}/{hit.get('osm_id')} '{hit.get('display_name')}' ({entry['date']})")
    return float(hit["lat"]), float(hit["lng"])


def build_shelters(spec: dict, ssis_rows: list[dict], raw_tables: dict[str, tuple[list[dict], str]],
                   geocache: dict, cat: rg.Catalog, report: Report) -> list[dict]:
    rows = {r["srv_inst_id"]: r for r in ssis_rows if r["kind"] in ("050107", "050108")}
    entries = {e["ssis"]: e for e in spec["entries"]}
    for x in spec.get("exclude", []):
        if x["ssis"] in rows:
            report.excluded.append(f"[잠자리 아님] {x['name']}: {x['reason']}")
            report.drops["잠자리: 낮 시설 제외"] += 1
    for ns in spec.get("not_shelters", []):
        report.excluded.append(f"[잠자리 아님] {ns['name']}: {ns['reason']}")
    for sid in entries:
        if sid not in rows:
            report.warnings.append(f"[잠자리] {entries[sid]['name']} ({sid}) 가 SSIS 목록에서 사라짐 — 폐지 여부 확인 필요")
    excluded = {x["ssis"] for x in spec.get("exclude", [])}
    out = []
    for sid in sorted(rows):
        if sid in excluded:
            continue
        r = rows[sid]
        e = entries.get(sid) or {"id": stable_id("shelter-ssis", sid), "name": r["name"]}
        if sid not in entries:
            report.warnings.append(f"[잠자리] SSIS 새 시설 '{r['name']}' — 보정 항목 없이 기본값으로 넣음, 검토 필요")
        name = e["name"]
        label = f"[잠자리] {name}"
        addr_raw = e.get("address") or ssis_address(r)
        sido, rest = rg.normalize_sido(addr_raw)
        phone_raw = e.get("phone") or r["phone"]

        # 교차 확인: 원본 CSV(cross_check) + 조사 문서 값(checks)
        checks = list(e.get("checks", []))
        raw_coords = None
        for cc in e.get("cross_check", []):
            rows_cc, raw_date = raw_tables[cc["source_id"]]
            cols = RAW_TABLES[cc["source_id"]]
            x = next((y for y in rows_cc if all((y.get(k) or "").strip() == v for k, v in cc["key"].items())), None)
            if x is None:
                report.warnings.append(f"{label}: 교차 확인 원본 {cc['source_id']} {cc['key']} 에 없음")
                continue
            cc_addr = " ".join((x.get(c) or "").strip() for c in cols["addr"])
            same = address_core(cc_addr) == address_core(addr_raw)
            if not cc.get("coords_only"):
                chk = {"source": f"{cc['source_id']} ({x.get(cols.get('date', ''), '') or raw_date})", "address": cc_addr}
                if cols.get("phone"):
                    chk["phone"] = x.get(cols["phone"])
                checks.append(chk)
            if cols.get("lat") and x.get(cols["lat"]):
                if same:
                    raw_coords = (float(x[cols["lat"]]), float(x[cols["lng"]]), cc["source_id"])
                else:
                    report.mismatches.append(f"{label}: {cc['source_id']} 좌표는 옛 주소 '{cc_addr}' 기준이라 쓰지 않음")
        agree = compare_sources(label, addr_raw, normalize_phone(phone_raw) or phone_raw, checks, report)
        if agree == 0:
            report.warnings.append(f"{label}: SSIS 말고 주소·전화가 맞는 공식 출처를 찾지 못함 (출처 1개)")

        geocoded = False
        if e.get("coords"):
            c = e["coords"]
            lat, lng, coord_src = c["lat"], c["lng"], c["source_id"]
            if c.get("approximate"):
                report.to_verify.append(f"{name}: 좌표 근사값 — {c['reason']}")
        elif raw_coords:
            lat, lng, coord_src = raw_coords
        else:
            sigungu0, _ = cat.resolve_sigungu(sido, rest, dong_hints(addr_raw))
            got = geocoded_coords(geocode.query_for(r["addr"], r["addr_detail"]), sido, sigungu0, geocache, cat,
                                  report, label)
            if got is None:
                continue
            (lat, lng), coord_src, geocoded = got, "osm-nominatim", True
            report.to_verify.append(f"{name}: 좌표를 OSM 주소 검색으로 찾음 — 지도 위치 사람 확인 필요")
        sigungu, sg_warn = cat.resolve_sigungu(sido, rest, dong_hints(addr_raw), lat, lng)
        if sg_warn:
            report.warnings.append(f"{label}: {sg_warn}")
        phone, issue, check = clean_phone(phone_raw, sido, sigungu)
        if issue and check:
            report.to_verify.append(f"{name}: {issue}")
        verified_by = e.get("verified_by", "public_data")
        if verified_by == "public_data":
            report.to_verify.append(f"{name}: 운영시간·입소 조건 (공공데이터에 없음)")
        if e.get("note"):
            report.warnings.append(f"{label}: {e['note']}")
        f = {
            "id": e["id"], "name": name, "category": "shelter",
            "address": short_address(addr_raw), "lat": lat, "lng": lng, "phone": phone,
            "hours": e.get("hours", []),
            "hours_note": e.get("hours_note") or spec["default_hours_note"],
            "holiday_policy": e.get("holiday_policy"),
            "eligibility": e.get("eligibility") or spec["eligibility"],
            "requirements": e.get("requirements"), "cost": "free",
            "source_id": SSIS_SOURCE, "source_url": e.get("source_url"),
            "last_verified": e.get("last_verified") or SSIS_DATE, "verified_by": verified_by,
            "sido": sido, "sigungu": sigungu, "audience": "general",
            "_coord_source": coord_src,
        }
        if geocoded:
            f["geocoded"] = True
        out.append(f)
    return out


def build_ssis_meals(spec: dict, ssis_rows: list[dict], meals: list[dict], geocache: dict, cat: rg.Catalog,
                     report: Report) -> list[dict]:
    """SSIS 노숙인 급식시설(050109) 중 급식 표준데이터에 같은 주소가 없는 곳."""
    have = {(m["sido"], address_core(m["address"])) for m in meals}
    excluded = {x["ssis"]: x for x in spec.get("exclude", [])}
    out = []
    for r in sorted((x for x in ssis_rows if x["kind"] == "050109"), key=lambda x: x["srv_inst_id"]):
        sid = r["srv_inst_id"]
        label = f"[급식] {r['name']}"
        if sid in excluded:
            report.drop("보정: 제외", f"{label} — {excluded[sid]['reason']}")
            report.warnings.append(f"{label}: {excluded[sid]['reason']}")
            continue
        addr = ssis_address(r)
        sido, rest = rg.normalize_sido(addr)
        if (sido, address_core(addr)) in have:
            report.excluded.append(f"{label}: 급식 표준데이터에 같은 주소가 이미 있어 추가하지 않음")
            continue
        sigungu0, _ = cat.resolve_sigungu(sido, rest, dong_hints(addr))
        got = geocoded_coords(geocode.query_for(r["addr"], r["addr_detail"]), sido, sigungu0, geocache, cat,
                              report, label)
        if got is None:
            continue
        lat, lng = got
        sigungu, _ = cat.resolve_sigungu(sido, rest, dong_hints(addr), lat, lng)
        phone, issue, check = clean_phone(r["phone"], sido, sigungu)
        if issue and check:
            report.to_verify.append(f"{label}: {issue}")
        report.to_verify.append(f"{label}: 좌표를 OSM 주소 검색으로 찾음, 운영 요일·시간 없음 — 전화 확인 필요")
        out.append({
            "id": spec["ids"].get(sid) or stable_id("meal-ssis", sid), "name": spec["names"].get(sid, r["name"]),
            "category": "meal", "address": short_address(addr), "lat": lat, "lng": lng, "phone": phone,
            "hours": [], "hours_note": spec["hours_note"], "holiday_policy": None,
            "eligibility": spec["eligibility"], "requirements": None, "cost": "free",
            "source_id": SSIS_SOURCE, "last_verified": SSIS_DATE, "verified_by": "public_data",
            "sido": sido, "sigungu": sigungu, "audience": "general", "geocoded": True,
            "_coord_source": "osm-nominatim",
        })
    return out


# ---------- 진료 ----------

def build_clinics(spec: dict, hira_rows: list[dict], cat: rg.Catalog, report: Report,
                  kinds: list[str] | None = None) -> list[dict]:
    by_name = defaultdict(list)
    for h in hira_rows:
        by_name[h["name"]].append(h)
    used = set()
    out = []

    def base(h: dict) -> dict | None:
        sido, rest = rg.normalize_sido(h["address"])
        if sido is None:
            sido, _ = rg.normalize_sido(h.get("sido"))
        try:
            lat, lng = float(h["lat"]), float(h["lng"])
        except (TypeError, ValueError):
            return None
        sigungu, sg_warn = cat.resolve_sigungu(sido, rest, dong_hints(h["address"]) + [h.get("dong", "")], lat, lng)
        if sg_warn:
            report.warnings.append(f"[진료] {h['name']}: {sg_warn}")
        return {"sido": sido, "sigungu": sigungu, "lat": lat, "lng": lng, "address": short_address(h["address"])}

    for e in spec["entries"]:
        if e.get("exclude_reason"):
            line = f"[진료] {e['name']} ({e.get('sido', '')}): {e.get('note', '')}"
            (report.need_coords if e["exclude_reason"] == "좌표 필요" else report.excluded).append(line)
            report.drops[f"진료: {e['exclude_reason']}"] += 1
            continue
        hs = sorted(by_name.get(e["hira_name"], []), key=lambda h: h["ykiho"])
        if not hs:
            report.warnings.append(f"[진료] {e['name']}: HIRA 에서 '{e['hira_name']}' 를 찾지 못함 — 폐업 여부 확인 필요")
            continue
        if len(hs) > 1:
            report.warnings.append(f"[진료] {e['name']}: HIRA 에 같은 이름 {len(hs)}곳 — 첫 번째 사용")
        h = hs[0]
        used.add(h["ykiho"])
        b = base(h)
        if b is None:
            report.need_coords.append(f"[진료] {e['name']} — HIRA 에 좌표 없음")
            continue
        if e.get("phone"):
            phone = e["phone"]
        else:
            phone, issue, check = clean_phone(h["phone"], b["sido"], b["sigungu"])
            if issue and check:
                report.to_verify.append(f"{e['name']}: {issue}")
        out.append({
            "id": e["id"], "name": e["name"], "category": "clinic", "address": b["address"],
            "lat": b["lat"], "lng": b["lng"], "phone": phone,
            "hours": e.get("hours", []), "hours_note": e.get("hours_note"),
            "holiday_policy": e.get("holiday_policy"), "eligibility": e.get("eligibility"),
            "requirements": e.get("requirements"), "cost": e.get("cost", "free"),
            "source_id": e.get("source_id", "hira-hospital"), "source_url": e.get("source_url"),
            "last_verified": e["last_verified"], "verified_by": e["verified_by"], "_coord_source": "hira-hospital",
            "sido": b["sido"], "sigungu": b["sigungu"], "audience": "general", "subtype": e["subtype"],
        })

    hc = spec["health_center"]
    kinds = set(kinds if kinds is not None else hc["kinds"])
    skip = {x["hira_name"]: x["reason"] for x in hc.get("exclude", [])}
    for h in hira_rows:
        if h["kind"] not in kinds or h["ykiho"] in used:
            continue
        if h["name"] in skip:
            report.drop("보정: 제외", f"[진료] {h['name']} — {skip[h['name']]}")
            continue
        b = base(h)
        if b is None:
            report.drop("보건소: 좌표 없음", h["name"])
            continue
        phone, issue, check = clean_phone(h["phone"], b["sido"], b["sigungu"])
        if issue and check:
            report.to_verify.append(f"{h['name']}: {issue}")
        out.append({
            "id": stable_id("clinic-hc", h["ykiho"]), "name": h["name"], "category": "clinic",
            "address": b["address"], "lat": b["lat"], "lng": b["lng"], "phone": phone,
            "hours": [], "hours_note": hc["hours_note"], "holiday_policy": None,
            "eligibility": hc["eligibility"], "requirements": None, "cost": "low_cost",
            "source_id": "hira-hospital", "source_url": None, "last_verified": HIRA_AS_OF,
            "verified_by": "public_data", "sido": b["sido"], "sigungu": b["sigungu"], "audience": "general",
            "subtype": "health_center",
        })
    return out


# ---------- 전체 ----------

def load_json(root: Path, rel: str):
    return json.loads((root / rel).read_text(encoding="utf-8"))


def load_catalog(root: Path, src: dict) -> tuple[rg.Catalog, list[str]]:
    molit = rg.read_molit(root / src["molit-bjd"]["raw"])
    cents = rg.read_commented_csv(root / src["sgis-boundary"]["raw"])
    return rg.build_catalog(molit, cents)


def compact(f: dict) -> dict:
    """빈 선택 필드와 내부용('_')을 뺀다. geocoded 는 true 일 때만 둔다."""
    return {k: v for k, v in f.items() if not k.startswith("_") and not (k in OPTIONAL_KEYS and v is None)
            and not (k == "geocoded" and not v)}


def build(root: Path, version: str, today: date, health_kinds: list[str] | None = None) -> tuple[dict, list[dict], Report]:
    report = Report()
    sources = load_json(root, "data/curated/sources.json")
    src = {s["id"]: s for s in sources}
    holidays = load_json(root, "data/curated/holidays.json")
    cat, region_warnings = load_catalog(root, src)
    report.region_notes += region_warnings
    for (sido, raw), shown in rg.SIGUNGU_ALIASES.items():
        report.region_notes.append(
            f"⚠ {sido} '{raw}' 를 '{shown}' 로 표시함 (개발자 지시). 국토교통부 법정동 2026-07-29·HIRA 2026-09·서해구청 누리집은 "
            f"'{raw}', 법률 원문 검증(verify-legal-clinic-20261104.md B1)은 '{shown}'. 확인 후 regions.SIGUNGU_ALIASES 한 줄로 바꿀 수 있음")

    meal_rows = json.loads((root / src["national-free-meal-std"]["raw"]).read_text(encoding="utf-8"))
    facilities = build_meals(meal_rows, load_json(root, "data/overrides/meal.json")["entries"], cat, today, report)

    ssis_rows = read_csv(root / src[SSIS_SOURCE]["raw"])
    geocache = geocode.load_cache(root / "data/curated/geocode-cache.json")
    meal_spec = load_json(root, "data/overrides/meal.json")
    facilities += build_ssis_meals(meal_spec["ssis"], ssis_rows, facilities, geocache, cat, report)

    shelter_spec = load_json(root, "data/overrides/shelter.json")
    raw_tables = {}
    for sid in sorted({cc["source_id"] for e in shelter_spec["entries"] for cc in e.get("cross_check", [])}):
        p = root / src[sid]["raw"]
        raw_tables[sid] = (read_csv(p), raw_date_from_path(p))
    facilities += build_shelters(shelter_spec, ssis_rows, raw_tables, geocache, cat, report)

    hira = read_csv(root / src["hira-hospital"]["raw"])
    facilities += build_clinics(load_json(root, "data/overrides/clinic.json"), hira, cat, report, health_kinds)

    valid, ids = [], set()
    coord_sources = set()
    for f in facilities:
        errors = validate(f)
        if f["id"] in ids:
            errors.append("중복 id")
        if errors:
            report.drop("검증 실패", f"{f.get('name')} ({f.get('address')}): {errors}")
            continue
        for w in location_warnings(f, cat):
            report.warnings.append(f"[{f['category']}] {f['name']}: {w}")
        ids.add(f["id"])
        if f.get("_coord_source"):
            coord_sources.add(f["_coord_source"])
        valid.append(compact(f))
        if f.get("subtype") != "health_center":
            report.included.append(
                f"[{f['category']}{'/' + f['audience'] if f['audience'] == 'senior' else ''}] {f['name']} — "
                f"{f['address']} ({f.get('phone') or '전화 없음'}, {f['verified_by']})")

    used = {f["source_id"] for f in valid} | coord_sources | {"molit-bjd", "sgis-boundary"}
    missing = used - set(src)
    if missing:
        raise ValueError(f"sources.json 에 없는 출처: {sorted(missing)}")
    dataset = {
        "version": version,
        "holidays": holidays["dates"],
        "sources": [{k: s[k] for k in ("id", "name", "provider", "url", "license") if k in s}
                    for s in sources if s["id"] in used],
        "facilities": sorted(valid, key=lambda f: f["id"]),
    }
    return dataset, rg.regions_json(cat), report


def serialize(obj) -> bytes:
    return (json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")


def summarize(dataset: dict, regions: list[dict], sizes: dict, report: Report) -> None:
    fs = dataset["facilities"]
    cats = Counter(f["category"] for f in fs)
    subtypes = Counter(f.get("subtype") for f in fs if f["category"] == "clinic")
    aud = Counter(f["audience"] for f in fs if f["category"] == "meal")
    vb = Counter(f["verified_by"] for f in fs)
    by_sido = defaultdict(Counter)
    for f in fs:
        by_sido[f["sido"]][f["category"] if f.get("subtype") != "health_center" else "health_center"] += 1
        if f["category"] == "meal":
            by_sido[f["sido"]]["meal_" + f["audience"]] += 1
    lines = [
        f"- 시설 {len(fs)}곳: " + ", ".join(f"{k} {v}" for k, v in sorted(cats.items())),
        "- 진료 세부: " + ", ".join(f"{k} {v}" for k, v in sorted(subtypes.items())),
        f"- 급식 대상: general {aud['general']}, senior {aud['senior']}",
        "- 확인 방법: " + ", ".join(f"{k} {v}" for k, v in sorted(vb.items())),
        f"- 지역(시군구) {len(regions)}곳",
        f"- 파일 크기: facilities.json {sizes['facilities']:,} B (gzip {sizes['facilities_gz']:,} B), "
        f"regions.json {sizes['regions']:,} B (gzip {sizes['regions_gz']:,} B)",
        "",
        "| 시도 | 밥(누구나) | 밥(어르신) | 잠자리 | 무료진료·지원 | 보건소·지소 |",
        "|---|---|---|---|---|---|",
    ]
    for s in rg.SIDO_ORDER:
        c = by_sido.get(s, Counter())
        lines.append(f"| {s} | {c['meal_general']} | {c['meal_senior']} | {c['shelter']} | {c['clinic']} | {c['health_center']} |")
    report.summary = lines


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--today", required=True, help="빌드 기준일 YYYY-MM-DD (운영종료·1년 기준)")
    parser.add_argument("--version", required=True, help="데이터 버전 (ISO 8601, 예: 2026-11-04T18:00:00+09:00)")
    parser.add_argument("--out", default=str(ROOT / "app/assets/data/facilities.json"))
    parser.add_argument("--regions-out", default=str(ROOT / "app/assets/data/regions.json"))
    parser.add_argument("--report", default=str(ROOT / "data/build-report.md"))
    args = parser.parse_args(argv)
    today = parse_date(args.today)
    if today is None:
        parser.error("--today 형식은 YYYY-MM-DD")
    datetime.fromisoformat(args.version)

    dataset, regions, report = build(ROOT, args.version, today)
    if not dataset["facilities"] or not regions:
        print("시설 또는 지역이 0개 — 배포 파일을 쓰지 않음", file=sys.stderr)
        return 1
    fac_bytes, reg_bytes = serialize(dataset), serialize(regions)
    if len(fac_bytes) > SIZE_LIMIT:
        report.warnings.append(f"facilities.json 이 {len(fac_bytes):,} B 로 목표({SIZE_LIMIT:,} B)를 넘음")
    sizes = {"facilities": len(fac_bytes), "facilities_gz": len(gzip.compress(fac_bytes, mtime=0)),
             "regions": len(reg_bytes), "regions_gz": len(gzip.compress(reg_bytes, mtime=0))}
    summarize(dataset, regions, sizes, report)
    Path(args.out).write_bytes(fac_bytes)
    Path(args.regions_out).write_bytes(reg_bytes)
    Path(args.report).write_text(report.markdown(args.version, args.today), encoding="utf-8")
    print("\n".join(report.summary[:6]))
    print(f"뺀 행 {sum(report.drops.values())}, 경고 {len(report.warnings)}, 전화 확인 {len(report.to_verify)}, "
          f"좌표 필요 {len(report.need_coords)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
