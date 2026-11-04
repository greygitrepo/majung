"""큰 원본에서 앱 빌드에 필요한 작은 표를 뽑아 data/curated/derived/ 에 둔다.

큰 원본(SGIS 경계 SHP 약 450MB, HIRA 병의원 CSV 약 30MB)은 커밋하지 않는다(.gitignore).
그래서 build.py 는 여기서 만든 작은 CSV 만 읽는다. 원본을 새로 받으면 이 스크립트를 다시 돌린다.

    python3 -I pipeline/extract.py centroids   # 시군구 대표 좌표
    python3 -I pipeline/extract.py hira        # 보건소·보건지소·무료진료소 행

원본은 신뢰하지 않는 데이터로 다룬다: 읽기만 하고 실행하지 않는다.
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import re
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import geo  # noqa: E402
import regions  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SGIS_DIR = ROOT / "data/raw/sgis-admin-boundary_20261104/ex"
HIRA_CSV = ROOT / "data/raw/clinic_20261103/hira_20260930_extracted/1.병원정보서비스(2026.9.).csv"
MOLIT_CSV = ROOT / "data/raw/molit-bjd-national_20261104/molit_bjd_20260729.csv"
DERIVED = ROOT / "data/curated/derived"
CENTROIDS_CSV = DERIVED / "sigungu-centroids.csv"
DONG_ASSIGN_CSV = DERIVED / "new-district-dongs.csv"
HIRA_SUBSET_CSV = DERIVED / "hira-clinics-20260930.csv"
SSIS_DIR = ROOT / "data/raw/ssis-api_20261104"
SSIS_CSV = DERIVED / "ssis-facilities-20261104.csv"
SSIS_KINDS = {"050107": "종합지원센터", "050108": "일시보호시설", "050109": "급식시설", "050110": "진료시설"}
SSIS_FIELDS = ["kind", "kind_name", "srv_inst_id", "fclt_cd", "name", "addr", "addr_detail", "phone", "jrsd_sgg_cd"]

# SGIS 2025-2Q 에는 있지만 2026년에 나뉘거나 없어진 시군구 → 새 시군구 후보(법정동 이름 기준)
SUPERSEDED = {
    "23010": ("인천", ["제물포구", "영종구"]),   # 옛 중구
    "23020": ("인천", ["제물포구"]),             # 옛 동구
    "23080": ("인천", ["서해구", "검단구"]),     # 옛 서구 (법정동·HIRA 이름 그대로)
    "31240": ("경기", ["화성시 만세구", "화성시 효행구", "화성시 병점구", "화성시 동탄구"]),
}
HEALTH_KINDS = {"보건소", "보건의료원", "보건지소"}


def read_hira(path: Path = HIRA_CSV) -> list[dict]:
    raw = path.read_bytes()
    for enc in ("utf-8-sig", "cp949"):
        try:
            return list(csv.DictReader(io.StringIO(raw.decode(enc))))
        except UnicodeDecodeError:
            continue
    raise ValueError("HIRA 인코딩을 알 수 없음")


def hira_district(row: dict) -> tuple[str | None, str | None]:
    """HIRA 주소 → (시도, 법정동 파일식 시군구 이름: '서해구', '화성시 만세구')."""
    sido, rest = regions.normalize_sido(row.get("주소"))
    toks = rest.split()
    if not sido or not toks:
        return sido, None
    if len(toks) > 1 and toks[0].endswith("시") and toks[1].endswith("구"):
        return sido, f"{toks[0]} {toks[1]}"
    return sido, toks[0]


def assign_dongs(dongs: list[dict], points: list[tuple[str, float, float]], molit_dongs: dict) -> list[dict]:
    """행정동 → 새 시군구. ① 그 행정동 안의 HIRA 기관 주소 다수결 ② 법정동 이름이 한 후보에만 있음 ③ 가장 가까운 배정된 행정동."""
    for d in dongs:
        d["votes"] = Counter()
    for name, x, y in points:
        for d in dongs:
            if name not in d["candidates"]:
                continue
            x0, y0, x1, y1 = d["bbox"]
            if x0 <= x <= x1 and y0 <= y <= y1 and geo.point_in_rings(x, y, d["rings"]):
                d["votes"][name] += 1
                break
    for d in dongs:
        if len(d["candidates"]) == 1:
            d["district"], d["how"] = d["candidates"][0], "유일 후보"
        elif d["votes"]:
            top = d["votes"].most_common()
            d["district"] = top[0][0]
            d["how"] = f"HIRA {top[0][1]}/{sum(d['votes'].values())}"
        else:
            hits = [c for c in d["candidates"] if d["name"] in molit_dongs.get((d["sido"], c), set())]
            if len(hits) == 1:
                d["district"], d["how"] = hits[0], "법정동 이름"
            else:
                d["district"], d["how"] = None, None
    for d in dongs:
        if d["district"] is None:
            others = [o for o in dongs if o["district"] and o["old"] == d["old"] and o["how"] != "이웃"]
            best = min(others, key=lambda o: (o["cx"] - d["cx"]) ** 2 + (o["cy"] - d["cy"]) ** 2)
            d["district"], d["how"] = best["district"], "이웃"
    return dongs


def latlng_bbox(boxes: list[tuple[float, float, float, float]]) -> dict:
    """TM 상자들 → 위경도 상자(네 모서리를 역변환해 감싼다)."""
    x0 = min(b[0] for b in boxes); y0 = min(b[1] for b in boxes)
    x1 = max(b[2] for b in boxes); y1 = max(b[3] for b in boxes)
    pts = [geo.tm_inverse(x, y) for x in (x0, x1) for y in (y0, y1)]
    return {"min_lat": f"{min(p[0] for p in pts):.4f}", "min_lng": f"{min(p[1] for p in pts):.4f}",
            "max_lat": f"{max(p[0] for p in pts):.4f}", "max_lng": f"{max(p[1] for p in pts):.4f}"}


def extract_centroids() -> None:
    sgg_rows = geo.read_dbf(SGIS_DIR / "bnd_sigungu_00_2025_2Q.dbf")
    sgg_polys = geo.read_shp_polygons(SGIS_DIR / "bnd_sigungu_00_2025_2Q.shp")
    out = []
    for i, r in enumerate(sgg_rows):
        code = r["SIGUNGU_CD"]
        if code in SUPERSEDED:
            continue
        area, cx, cy = geo.rings_area_centroid(sgg_polys[i])
        lat, lng = geo.tm_inverse(cx, cy)
        out.append({"sido": regions.SGIS_SIDO[code[:2]], "sigungu": r["SIGUNGU_NM"], "lat": f"{lat:.5f}",
                    "lng": f"{lng:.5f}", "area_km2": f"{area / 1e6:.1f}", "source": f"SGIS 시군구 {code}",
                    "approximate": "", **latlng_bbox([geo.bbox(sgg_polys[i])])})

    # 새 시군구: 행정동 경계를 묶는다
    dong_rows = geo.read_dbf(SGIS_DIR / "bnd_dong_00_2025_2Q.dbf")
    wanted = {i for i, r in enumerate(dong_rows) if r["ADM_CD"][:5] in SUPERSEDED}
    polys = geo.read_shp_polygons(SGIS_DIR / "bnd_dong_00_2025_2Q.shp", wanted)
    dongs = []
    for i in sorted(wanted):
        r = dong_rows[i]
        sido, cands = SUPERSEDED[r["ADM_CD"][:5]]
        area, cx, cy = geo.rings_area_centroid(polys[i])
        dongs.append({"code": r["ADM_CD"], "name": r["ADM_NM"], "old": r["ADM_CD"][:5], "sido": sido,
                      "candidates": cands, "rings": polys[i], "bbox": geo.bbox(polys[i]),
                      "area": area, "cx": cx, "cy": cy})
    all_targets = {(s, c) for s, cs in SUPERSEDED.values() for c in cs}
    points = []
    for h in read_hira():
        sido, name = hira_district(h)
        if (sido, name) in all_targets and h.get("좌표(X)") and h.get("좌표(Y)"):
            x, y = geo.tm_forward(float(h["좌표(Y)"]), float(h["좌표(X)"]))
            points.append((name, x, y))
    points.sort()
    molit = regions.read_molit(MOLIT_CSV)
    parents = {r[2] for r in molit if r[2] and not r[3]}
    molit_dongs = defaultdict(set)
    for r in molit:
        if r[2] and r[3]:
            s, _ = regions.normalize_sido(r[1])
            molit_dongs[(s, regions.molit_name(r[2], parents))].add(r[3])
    assign_dongs(dongs, points, molit_dongs)

    by_target = defaultdict(list)
    for d in dongs:
        by_target[(d["sido"], d["district"])].append(d)
    for (sido, name), ds in sorted(by_target.items()):
        area, cx, cy = geo.weighted_centroid([(d["area"], d["cx"], d["cy"]) for d in ds])
        lat, lng = geo.tm_inverse(cx, cy)
        hows = Counter(d["how"].split(" ")[0] for d in ds)
        note = (f"SGIS 행정동 {len(ds)}개를 묶은 면적중심 (배정: "
                + ", ".join(f"{k} {v}" for k, v in sorted(hows.items())) + ")")
        out.append({"sido": sido, "sigungu": name, "lat": f"{lat:.5f}", "lng": f"{lng:.5f}",
                    "area_km2": f"{area / 1e6:.1f}", "source": "SGIS 행정동 2025-2Q + HIRA 2026-09 주소",
                    "approximate": note, **latlng_bbox([d["bbox"] for d in ds])})
    for s, cs in SUPERSEDED.values():
        for c in cs:
            if (s, c) not in by_target:
                print(f"경고: {s} {c} 에 배정된 행정동 없음", file=sys.stderr)

    DERIVED.mkdir(parents=True, exist_ok=True)
    header = ("# 시군구 대표 좌표 (면적중심, WGS84). pipeline/extract.py centroids 로 생성. 손으로 고치지 않는다.\n"
              "# 원본: 국가데이터처 SGIS 행정구역 경계 2025-2Q (data.go.kr 15129688, 이용허락범위 제한 없음, 받은 날 2026-11-04).\n"
              "# 2026년에 생긴 인천 제물포·영종·서해·검단구, 화성 4개 구는 SGIS 시군구 경계에 없어서 행정동 경계를 묶었다.\n"
              "# 행정동→새 구 배정은 HIRA 병의원 현황 2026-09 의 새 주소 다수결(공식 매핑 자료 없음) → approximate 칸에 표시.\n")
    fields = ["sido", "sigungu", "lat", "lng", "area_km2", "source", "approximate",
              "min_lat", "min_lng", "max_lat", "max_lng"]
    _write_csv(CENTROIDS_CSV, header, fields, out)
    assign = [{"old_sigungu_code": d["old"], "adm_cd": d["code"], "adm_nm": d["name"], "district": d["district"],
               "how": d["how"]} for d in dongs]
    _write_csv(DONG_ASSIGN_CSV, "# 새 시군구 행정동 배정 (검토용). pipeline/extract.py centroids 가 만든다.\n",
               ["old_sigungu_code", "adm_cd", "adm_nm", "district", "how"], assign)
    print(f"시군구 {len(out)}행 → {CENTROIDS_CSV.relative_to(ROOT)}")


def extract_hira() -> None:
    overrides = json.loads((ROOT / "data/overrides/clinic.json").read_text(encoding="utf-8"))
    names = {e["hira_name"] for e in overrides["entries"] if e.get("hira_name")}
    rows = []
    for h in read_hira():
        if h["종별코드명"] in HEALTH_KINDS or h["요양기관명"] in names:
            rows.append({"ykiho": h["암호화요양기호"], "name": h["요양기관명"], "kind": h["종별코드명"],
                         "sido": h["시도코드명"], "address": h["주소"], "dong": h["읍면동"],
                         "phone": h["전화번호"], "lng": h["좌표(X)"], "lat": h["좌표(Y)"]})
    rows.sort(key=lambda r: (r["sido"], r["address"], r["name"], r["ykiho"]))
    found = {r["name"] for r in rows}
    for n in sorted(names - found):
        print(f"경고: HIRA 에 없음: {n}", file=sys.stderr)
    header = ("# HIRA 전국 병의원 및 약국 현황 2026.9 (data.go.kr 15051059, 공공누리 1유형, 기준일 2026-09-30) 중\n"
              "# 보건소·보건의료원·보건지소 + data/overrides/clinic.json 의 hira_name 행만. pipeline/extract.py hira 로 생성.\n")
    _write_csv(HIRA_SUBSET_CSV, header, ["ykiho", "name", "kind", "sido", "address", "dong", "phone", "lng", "lat"], rows)
    print(f"HIRA {len(rows)}행 → {HIRA_SUBSET_CSV.relative_to(ROOT)}")


def parse_ssis_bass(xml_bytes: bytes) -> list[dict]:
    """getFcltByBassInfoInqire2 응답 → 행. 대표자명(rprsNm)·사업자번호 같은 개인·불필요 정보는 버린다."""
    import xml.etree.ElementTree as ET
    root = ET.fromstring(xml_bytes)
    if (root.findtext("header/resultCode") or "").strip() != "00":
        raise ValueError(f"SSIS 응답 오류: {root.findtext('header/resultMsg')}")
    out = []
    for it in root.iter("item"):
        g = lambda k: re.sub(r"\s+", " ", it.findtext(k) or "").strip()  # noqa: E731
        kind = g("fcltKindCd")
        out.append({"kind": kind, "kind_name": SSIS_KINDS.get(kind, ""), "srv_inst_id": g("srvInstId"),
                    "fclt_cd": g("fcltCd"), "name": g("fcltNm"), "addr": g("fcltAddr"),
                    "addr_detail": g("fcltDtl_1Addr"), "phone": g("fcltTelNo"), "jrsd_sgg_cd": g("jrsdSggCd")})
    return out


def extract_ssis() -> None:
    rows = []
    for path in sorted((SSIS_DIR / "bass").glob("*.xml")):
        if path.name[:6] not in SSIS_KINDS:
            continue  # 생활시설(050104~6)·쪽방상담소(050111)는 쓰지 않음
        rows += parse_ssis_bass(path.read_bytes())
    rows.sort(key=lambda r: (r["kind"], r["srv_inst_id"]))
    header = ("# 한국사회보장정보원_사회복지시설정보서비스 (data.go.kr 15001848, 이용허락범위 제한 없음) getFcltByBassInfoInqire2,\n"
              "# 받은 날 2026-11-04 (data/raw/ssis-api_20261104/bass/). 노숙인 종합지원센터(050107)·일시보호(050108)·급식(050109)·진료(050110)만.\n"
              "# 대표자명 등 개인 정보는 뺐다. 서비스 키는 들어 있지 않다. pipeline/extract.py ssis 로 생성.\n")
    _write_csv(SSIS_CSV, header, SSIS_FIELDS, rows)
    print(f"SSIS {len(rows)}행 → {SSIS_CSV.relative_to(ROOT)}")


def _write_csv(path: Path, header: str, fields: list[str], rows: list[dict]) -> None:
    buf = io.StringIO()
    buf.write(header)
    w = csv.DictWriter(buf, fieldnames=fields, lineterminator="\n")
    w.writeheader()
    w.writerows(rows)
    path.write_text(buf.getvalue(), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("what", choices=["centroids", "hira", "ssis"])
    args = p.parse_args(argv)
    {"centroids": extract_centroids, "hira": extract_hira, "ssis": extract_ssis}[args.what]()
    return 0


if __name__ == "__main__":
    sys.exit(main())
