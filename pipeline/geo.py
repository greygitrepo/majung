"""행정구역 경계(SHP) → 대표 좌표 계산. 표준 라이브러리만 쓴다.

data/research/regions/centroid_draft.py 를 옮긴 것이다.
- SGIS 경계는 EPSG:5179 (GRS80, TM, 중앙경선 127.5, 원점 위도 38, k0 0.9996, FE 1,000,000, FN 2,000,000).
- 중심점은 면적가중(다각형 무게중심). 섬·구멍(링 방향)이 있어도 부호 있는 면적을 더하므로 맞게 나온다.
"""
from __future__ import annotations

import math
import struct
from pathlib import Path

# GRS80
_A = 6378137.0
_F = 1 / 298.257222101
_E2 = _F * (2 - _F)
_EP2 = _E2 / (1 - _E2)
LON0, LAT0, K0, FE, FN = 127.5, 38.0, 0.9996, 1000000.0, 2000000.0


def _meridian(phi: float) -> float:
    e2 = _E2
    return _A * ((1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256) * phi
                 - (3 * e2 / 8 + 3 * e2 ** 2 / 32 + 45 * e2 ** 3 / 1024) * math.sin(2 * phi)
                 + (15 * e2 ** 2 / 256 + 45 * e2 ** 3 / 1024) * math.sin(4 * phi)
                 - (35 * e2 ** 3 / 3072) * math.sin(6 * phi))


def tm_inverse(x: float, y: float) -> tuple[float, float]:
    """EPSG:5179 (x, y) → (lat, lng)."""
    e2 = _E2
    m = _meridian(math.radians(LAT0)) + (y - FN) / K0
    mu = m / (_A * (1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256))
    e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2))
    phi1 = (mu + (3 * e1 / 2 - 27 * e1 ** 3 / 32) * math.sin(2 * mu)
            + (21 * e1 ** 2 / 16 - 55 * e1 ** 4 / 32) * math.sin(4 * mu)
            + (151 * e1 ** 3 / 96) * math.sin(6 * mu)
            + (1097 * e1 ** 4 / 512) * math.sin(8 * mu))
    c1 = _EP2 * math.cos(phi1) ** 2
    t1 = math.tan(phi1) ** 2
    n1 = _A / math.sqrt(1 - e2 * math.sin(phi1) ** 2)
    r1 = _A * (1 - e2) / (1 - e2 * math.sin(phi1) ** 2) ** 1.5
    d = (x - FE) / (n1 * K0)
    lat = phi1 - (n1 * math.tan(phi1) / r1) * (
        d ** 2 / 2 - (5 + 3 * t1 + 10 * c1 - 4 * c1 ** 2 - 9 * _EP2) * d ** 4 / 24
        + (61 + 90 * t1 + 298 * c1 + 45 * t1 ** 2 - 252 * _EP2 - 3 * c1 ** 2) * d ** 6 / 720)
    lon = (d - (1 + 2 * t1 + c1) * d ** 3 / 6
           + (5 - 2 * c1 + 28 * t1 + 3 * c1 ** 2 + 8 * _EP2 + 24 * t1 ** 2) * d ** 5 / 120) / math.cos(phi1)
    return math.degrees(lat), LON0 + math.degrees(lon)


def tm_forward(lat: float, lng: float) -> tuple[float, float]:
    """(lat, lng) → EPSG:5179 (x, y). Snyder (1987) 식 8-9, 8-10."""
    phi = math.radians(lat)
    lam = math.radians(lng - LON0)
    n = _A / math.sqrt(1 - _E2 * math.sin(phi) ** 2)
    t = math.tan(phi) ** 2
    c = _EP2 * math.cos(phi) ** 2
    a = lam * math.cos(phi)
    m = _meridian(phi)
    m0 = _meridian(math.radians(LAT0))
    x = FE + K0 * n * (a + (1 - t + c) * a ** 3 / 6 + (5 - 18 * t + t ** 2 + 72 * c - 58 * _EP2) * a ** 5 / 120)
    y = FN + K0 * (m - m0 + n * math.tan(phi) * (
        a ** 2 / 2 + (5 - t + 9 * c + 4 * c ** 2) * a ** 4 / 24
        + (61 - 58 * t + t ** 2 + 600 * c - 330 * _EP2) * a ** 6 / 720))
    return x, y


# ---------- DBF / SHP ----------

def read_dbf(path: Path, enc: str = "utf-8") -> list[dict]:
    data = Path(path).read_bytes()
    n = struct.unpack("<I", data[4:8])[0]
    hlen, rlen = struct.unpack("<HH", data[8:12])
    fields, off = [], 32
    while data[off] != 0x0D:
        name = data[off:off + 11].split(b"\0")[0].decode("ascii")
        fields.append((name, data[off + 16]))
        off += 32
    rows = []
    for i in range(n):
        rec = data[hlen + i * rlen: hlen + (i + 1) * rlen]
        p, row = 1, {}
        for name, flen in fields:
            row[name] = rec[p:p + flen].decode(enc, "replace").strip()
            p += flen
        rows.append(row)
    return rows


def _parse_polygon(rec: bytes) -> list[list[tuple[float, float]]]:
    shape_type = struct.unpack("<i", rec[:4])[0]
    if shape_type == 0:
        return []
    if shape_type not in (5, 15, 25):
        raise ValueError(f"다각형이 아닌 도형: {shape_type}")
    nparts, npts = struct.unpack("<ii", rec[36:44])
    parts = list(struct.unpack(f"<{nparts}i", rec[44:44 + 4 * nparts])) + [npts]
    base = 44 + 4 * nparts
    pts = struct.unpack(f"<{2 * npts}d", rec[base:base + 16 * npts])
    return [[(pts[2 * j], pts[2 * j + 1]) for j in range(parts[k], parts[k + 1])] for k in range(nparts)]


def read_shp_polygons(path: Path, wanted: set[int] | None = None) -> dict[int, list[list[tuple[float, float]]]]:
    """레코드 번호(0부터) → 링 목록. wanted 를 주면 .shx 색인으로 그 레코드만 읽는다."""
    path = Path(path)
    out: dict[int, list] = {}
    shx = path.with_suffix(".shx")
    with path.open("rb") as f:
        if wanted is not None and shx.exists():
            idx = shx.read_bytes()[100:]
            for i in sorted(wanted):
                off, clen = struct.unpack(">ii", idx[8 * i: 8 * i + 8])
                f.seek(off * 2 + 8)
                out[i] = _parse_polygon(f.read(clen * 2))
            return out
        f.seek(100)
        i = 0
        while True:
            hdr = f.read(8)
            if len(hdr) < 8:
                break
            _, clen = struct.unpack(">ii", hdr)
            rec = f.read(clen * 2)
            if wanted is None or i in wanted:
                out[i] = _parse_polygon(rec)
            i += 1
    return out


def rings_area_centroid(rings: list[list[tuple[float, float]]]) -> tuple[float, float, float]:
    """(면적, cx, cy). 링마다 부호 있는 면적을 더한다(SHP: 바깥 시계방향, 구멍 반시계)."""
    a = cx = cy = 0.0
    for ring in rings:
        for (x0, y0), (x1, y1) in zip(ring, ring[1:]):
            c = x0 * y1 - x1 * y0
            a += c
            cx += (x0 + x1) * c
            cy += (y0 + y1) * c
    a /= 2
    if a == 0:
        raise ValueError("면적 0")
    return abs(a), cx / (6 * a), cy / (6 * a)


def bbox(rings: list[list[tuple[float, float]]]) -> tuple[float, float, float, float]:
    xs = [x for r in rings for x, _ in r]
    ys = [y for r in rings for _, y in r]
    return min(xs), min(ys), max(xs), max(ys)


def point_in_rings(x: float, y: float, rings: list[list[tuple[float, float]]]) -> bool:
    """짝홀 규칙(구멍은 자동으로 빠짐)."""
    inside = False
    for ring in rings:
        for (x0, y0), (x1, y1) in zip(ring, ring[1:]):
            if (y0 > y) != (y1 > y) and x < (x1 - x0) * (y - y0) / (y1 - y0) + x0:
                inside = not inside
    return inside


def weighted_centroid(parts: list[tuple[float, float, float]]) -> tuple[float, float, float]:
    """[(면적, cx, cy)] → 합친 (면적, cx, cy)."""
    total = sum(p[0] for p in parts)
    return total, sum(p[0] * p[1] for p in parts) / total, sum(p[0] * p[2] for p in parts) / total
