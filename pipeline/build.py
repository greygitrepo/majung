"""공공데이터 원본 + 사람이 검토한 보정(data/curated) → 앱 데이터(app/assets/data/facilities.json).

사용법:
    python3 -I pipeline/build.py [--version 2026-11-03T22:00:00+09:00]

표준 라이브러리만 쓴다. 같은 입력이면 같은 출력이 나온다(--version 고정 시).
검증에 실패한 시설은 넣지 않고 보고서(data/build-report.md)에 남긴다.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KST = timezone(timedelta(hours=9))
DAYS = {"mon", "tue", "wed", "thu", "fri", "sat", "sun"}
CATEGORIES = {"meal", "shelter", "foodbank", "foodmarket", "shower", "laundry", "clinic", "counseling"}


@dataclass
class Report:
    included: list[str] = field(default_factory=list)
    excluded: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    to_verify: list[str] = field(default_factory=list)

    def markdown(self, version: str) -> str:
        def section(title: str, items: list[str]) -> str:
            body = "\n".join(f"- {i}" for i in items) if items else "- (없음)"
            return f"## {title} ({len(items)})\n\n{body}\n"

        return "\n".join([
            "# 데이터 빌드 보고서",
            "",
            f"버전: {version}",
            "",
            section("포함", self.included),
            section("제외", self.excluded),
            section("경고 — 사람이 검토해야 함", self.warnings),
            section("전화 확인 필요", self.to_verify),
        ])


# ---------- 정규화 ----------

def normalize_phone(raw: str | None) -> str | None:
    """'027775217' → '02-777-5217', '0220691600' → '02-2069-1600'. 형식이 안 맞으면 None."""
    if not raw:
        return None
    d = re.sub(r"\D", "", raw)
    if not d:
        return None
    if re.fullmatch(r"1[5-9]\d{6}", d):
        return f"{d[:4]}-{d[4:]}"
    if d.startswith("02") and len(d) in (9, 10):
        return f"02-{d[2:-4]}-{d[-4:]}"
    if re.fullmatch(r"0\d{9,10}", d):
        return f"{d[:3]}-{d[3:-4]}-{d[-4:]}"
    return None


def is_valid_phone(p: str) -> bool:
    d = re.sub(r"[\s\-()]", "", p)
    return bool(
        re.fullmatch(r"1\d{2}", d) or re.fullmatch(r"1[5-9]\d{6}", d) or re.fullmatch(r"0\d{8,10}", d)
    )


def short_address(addr: str) -> str:
    addr = re.sub(r"\s+", " ", addr).strip()
    return re.sub(r"^서울특별시 ", "서울 ", addr)


def eligibility_text(target: str | None) -> str | None:
    """원문 대상 표기를 낙인 없는 쉬운 말로 (docs/policy/ux-accessibility.md §2)."""
    if not target:
        return None
    parts = [p.strip() for p in re.split(r"[+,/]", target) if p.strip()]
    mapping = {"노숙인": "노숙 중인 분", "주거취약계층": "집이 불안정한 분", "누구나": "누구나"}
    return ", ".join(mapping.get(p, p) for p in parts)


# ---------- 검증 (앱 Facility.fromJson 과 같은 규칙) ----------

def validate(f: dict) -> list[str]:
    errors = []
    for key in ("id", "name", "category", "address", "source_id", "last_verified"):
        if not isinstance(f.get(key), str) or not f[key].strip():
            errors.append(f"필수 필드 없음: {key}")
    if f.get("category") not in CATEGORIES:
        errors.append(f"알 수 없는 분류: {f.get('category')}")
    lat, lng = f.get("lat"), f.get("lng")
    if not isinstance(lat, (int, float)) or not isinstance(lng, (int, float)):
        errors.append("좌표 없음")
    elif not (33.0 <= lat <= 38.7 and 124.5 <= lng <= 132.0):
        errors.append(f"좌표가 국내 범위 밖: {lat}, {lng}")
    if f.get("phone") and not is_valid_phone(f["phone"]):
        errors.append(f"전화번호 형식 오류: {f['phone']}")
    for rule in f.get("hours") or []:
        if not rule.get("days") or not set(rule["days"]) <= DAYS:
            errors.append(f"요일 오류: {rule.get('days')}")
        for k in ("open", "close"):
            if not re.fullmatch(r"([01]?\d|2[0-4]):[0-5]\d", str(rule.get(k, ""))):
                errors.append(f"시간 형식 오류: {rule.get(k)}")
    try:
        datetime.strptime(f.get("last_verified", ""), "%Y-%m-%d")
    except ValueError:
        errors.append(f"날짜 형식 오류: {f.get('last_verified')}")
    return errors


# ---------- 원본 읽기 ----------

def read_csv(path: Path) -> list[dict]:
    for enc in ("utf-8-sig", "cp949"):
        try:
            with path.open(encoding=enc, newline="") as fh:
                return list(csv.DictReader(fh))
        except UnicodeDecodeError:
            continue
    raise ValueError(f"인코딩을 알 수 없음: {path}")


def raw_date_from_path(path: Path) -> str:
    m = re.search(r"_(\d{4})(\d{2})(\d{2})", str(path))
    if not m:
        raise ValueError(f"원본 폴더 이름에 날짜가 없음: {path}")
    return f"{m.group(1)}-{m.group(2)}-{m.group(3)}"


# ---------- 변환 ----------

def build_meals(rows: list[dict], curated: dict, report: Report) -> list[dict]:
    out = []
    entries = curated["entries"]
    seen = set()
    for r in rows:
        addr = r.get("RDNMADR") or r.get("LNMADR") or ""
        if "서울특별시" not in addr or not any(f" {gu} " in f" {addr} " for gu in curated["target_gu"]):
            continue
        name = (r.get("FCLTY_NM") or "").strip()
        seen.add(name)
        entry = entries.get(name)
        if entry is None:
            report.warnings.append(f"[급식] 새 시설 '{name}' ({addr}) — data/curated 에 검토 항목 추가 필요")
            continue
        if "exclude" in entry:
            report.excluded.append(f"[급식] {name}: {entry['exclude']}")
            continue
        if r.get("OPER_CLOSE_DATE"):
            report.excluded.append(f"[급식] {name}: 원본에 운영종료일 {r['OPER_CLOSE_DATE']}")
            continue

        hours = entry.get("hours", [])
        note = entry.get("hours_note")
        changed = {k: r.get(k) for k, v in entry.get("expect_raw", {}).items() if (r.get(k) or "") != v}
        if changed:
            report.warnings.append(f"[급식] {name}: 원본 운영 문구가 바뀜 {changed} — 운영시간 구조화를 버리고 '확인 필요'로 표시")
            hours = []
            note = f"공공데이터 안내: {r.get('MLSV_DATE', '')} / {r.get('MLSV_TIME', '')}"

        raw_phone = r.get("PHONE_NUMBER")
        phone = entry.get("phone") or normalize_phone(raw_phone)
        if entry.get("phone"):
            report.to_verify.append(f"{name}: 전화번호 보정 ({raw_phone!r} → {entry['phone']}) — {entry.get('phone_reason', '')}")
        elif raw_phone and phone is None:
            report.warnings.append(f"[급식] {name}: 전화번호 형식 오류 {raw_phone!r} → 비움")
        if not phone:
            report.to_verify.append(f"{name}: 전화번호 없음")
        if not hours:
            report.to_verify.append(f"{name}: 끝나는 시간 등 운영시간 구조화 불가 — 전화로 확인")

        try:
            lat, lng = float(r.get("LATITUDE") or "x"), float(r.get("LONGITUDE") or "x")
        except ValueError:
            lat = lng = None

        out.append({
            "id": entry["id"],
            "name": entry.get("name", name),
            "category": "meal",
            "address": short_address(addr),
            "lat": lat,
            "lng": lng,
            "phone": phone,
            "hours": hours,
            "hours_note": note,
            "holiday_policy": None,
            "eligibility": eligibility_text(r.get("MLSV_TRGET")),
            "requirements": None,
            "cost": "free",
            "source_id": curated["source_id"],
            "last_verified": r.get("REFERENCE_DATE") or "",
            "verified_by": "public_data",
        })
    for name, entry in entries.items():
        if name not in seen and "exclude" not in entry:
            report.warnings.append(f"[급식] '{name}' 이 원본에서 사라짐 — 폐지 여부 확인 필요")
    return out


def build_shelters(rows: list[dict], curated: dict, raw_date: str, report: Report) -> list[dict]:
    by_code = {r.get("시설코드", "").strip(): r for r in rows}
    out = []
    for code, entry in curated["entries"].items():
        r = by_code.get(code)
        if r is None:
            report.warnings.append(f"[잠자리] 시설코드 {code} ({entry.get('name')}) 가 원본에서 사라짐 — 폐지 여부 확인 필요")
            continue
        addr = f"{r.get('시설주소', '')} {r.get('시설상세1주소', '')}"
        coords = entry["coords"]
        if coords.get("approximate"):
            report.to_verify.append(f"{entry['name']}: 좌표 근사값 — {coords['reason']}")
        if entry.get("note"):
            report.warnings.append(f"[잠자리] {entry['name']}: {entry['note']}")
        phone = normalize_phone(r.get("시설전화번호"))
        report.to_verify.append(f"{entry['name']}: 운영시간·입소 조건 (공공데이터에 없음)")
        out.append({
            "id": entry["id"],
            "name": entry["name"],
            "category": "shelter",
            "address": entry.get("address") or short_address(addr),
            "lat": coords["lat"],
            "lng": coords["lng"],
            "phone": phone,
            "hours": entry.get("hours", []),
            "hours_note": entry.get("hours_note"),
            "holiday_policy": None,
            "eligibility": curated["eligibility"],
            "requirements": None,
            "cost": "free",
            "source_id": curated["source_id"],
            "last_verified": raw_date,
            "verified_by": "public_data",
        })
    return out


def build(root: Path, version: str) -> tuple[dict, Report]:
    report = Report()
    sources = json.loads((root / "data/curated/sources.json").read_text(encoding="utf-8"))
    curated = json.loads((root / "data/curated/facilities.json").read_text(encoding="utf-8"))
    src = {s["id"]: s for s in sources}

    meal_rows = json.loads((root / src["national-free-meal-std"]["raw"]).read_text(encoding="utf-8"))
    shelter_path = root / src["ssis-welfare-basic"]["raw"]
    facilities = build_meals(meal_rows, curated["meal"], report)
    facilities += build_shelters(read_csv(shelter_path), curated["shelter"], raw_date_from_path(shelter_path), report)

    valid, ids = [], set()
    for f in facilities:
        errors = validate(f)
        if f["id"] in ids:
            errors.append("중복 id")
        if errors:
            report.excluded.append(f"{f.get('name')}: 검증 실패 {errors}")
            continue
        ids.add(f["id"])
        valid.append(f)
        report.included.append(f"[{f['category']}] {f['name']} — {f['address']} ({f.get('phone') or '전화 없음'})")

    used = {f["source_id"] for f in valid} | {"seoul-welfare-fac-gu", "hira-hospital", "seoul-heat-shelter", "osm-nominatim"}
    dataset = {
        "version": version,
        "holidays": curated["holidays"]["dates"],
        "sources": [
            {k: s[k] for k in ("id", "name", "provider", "url", "license") if k in s}
            for s in sources if s["id"] in used
        ],
        "facilities": sorted(valid, key=lambda f: f["id"]),
    }
    return dataset, report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default=datetime.now(KST).replace(microsecond=0).isoformat())
    parser.add_argument("--out", default=str(ROOT / "app/assets/data/facilities.json"))
    parser.add_argument("--report", default=str(ROOT / "data/build-report.md"))
    args = parser.parse_args(argv)

    dataset, report = build(ROOT, args.version)
    if not dataset["facilities"]:
        print("시설이 0개 — 배포 파일을 쓰지 않음", file=sys.stderr)
        return 1
    Path(args.out).write_text(json.dumps(dataset, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    Path(args.report).write_text(report.markdown(args.version), encoding="utf-8")
    print(f"시설 {len(dataset['facilities'])}곳, 제외 {len(report.excluded)}, 경고 {len(report.warnings)}, 확인 필요 {len(report.to_verify)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
