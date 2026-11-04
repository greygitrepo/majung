"""SGIS 경계 shp -> 면적가중 중심점(WGS84). 외부 라이브러리 없이 동작 (조사용 검증 스크립트)."""
import math
import struct
import sys


def read_dbf(path, enc="utf-8"):
    with open(path, "rb") as f:
        data = f.read()
    n = struct.unpack("<I", data[4:8])[0]
    hlen, rlen = struct.unpack("<HH", data[8:12])
    fields = []
    off = 32
    while data[off] != 0x0D:
        name = data[off:off + 11].split(b"\0")[0].decode("ascii")
        flen = data[off + 16]
        fields.append((name, flen))
        off += 32
    rows = []
    for i in range(n):
        r = data[hlen + i * rlen: hlen + (i + 1) * rlen]
        p = 1
        row = {}
        for name, flen in fields:
            row[name] = r[p:p + flen].decode(enc, "replace").strip()
            p += flen
        rows.append(row)
    return rows


def read_shp_centroids(path):
    out = []
    with open(path, "rb") as f:
        f.seek(100)
        while True:
            hdr = f.read(8)
            if len(hdr) < 8:
                break
            _, clen = struct.unpack(">ii", hdr)
            rec = f.read(clen * 2)
            st = struct.unpack("<i", rec[:4])[0]
            if st == 0:
                out.append(None)
                continue
            nparts, npts = struct.unpack("<ii", rec[36:44])
            parts = list(struct.unpack("<%di" % nparts, rec[44:44 + 4 * nparts])) + [npts]
            base = 44 + 4 * nparts
            pts = struct.unpack("<%dd" % (2 * npts), rec[base:base + 16 * npts])
            A = cx = cy = 0.0
            for k in range(nparts):
                a = parts[k]
                b = parts[k + 1]
                for j in range(a, b - 1):
                    x0, y0 = pts[2 * j], pts[2 * j + 1]
                    x1, y1 = pts[2 * j + 2], pts[2 * j + 3]
                    c = x0 * y1 - x1 * y0
                    A += c
                    cx += (x0 + x1) * c
                    cy += (y0 + y1) * c
            A /= 2
            out.append((cx / (6 * A), cy / (6 * A)))
    return out


def tm_inverse(x, y, lon0=127.5, lat0=38.0, k0=0.9996, fe=1000000.0, fn=2000000.0):
    a = 6378137.0
    f = 1 / 298.257222101
    e2 = f * (2 - f)
    ep2 = e2 / (1 - e2)

    def M(phi):
        return a * ((1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256) * phi
                    - (3 * e2 / 8 + 3 * e2 ** 2 / 32 + 45 * e2 ** 3 / 1024) * math.sin(2 * phi)
                    + (15 * e2 ** 2 / 256 + 45 * e2 ** 3 / 1024) * math.sin(4 * phi)
                    - (35 * e2 ** 3 / 3072) * math.sin(6 * phi))

    m = M(math.radians(lat0)) + (y - fn) / k0
    mu = m / (a * (1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256))
    e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2))
    phi1 = (mu + (3 * e1 / 2 - 27 * e1 ** 3 / 32) * math.sin(2 * mu)
            + (21 * e1 ** 2 / 16 - 55 * e1 ** 4 / 32) * math.sin(4 * mu)
            + (151 * e1 ** 3 / 96) * math.sin(6 * mu)
            + (1097 * e1 ** 4 / 512) * math.sin(8 * mu))
    C1 = ep2 * math.cos(phi1) ** 2
    T1 = math.tan(phi1) ** 2
    N1 = a / math.sqrt(1 - e2 * math.sin(phi1) ** 2)
    R1 = a * (1 - e2) / (1 - e2 * math.sin(phi1) ** 2) ** 1.5
    D = (x - fe) / (N1 * k0)
    lat = phi1 - (N1 * math.tan(phi1) / R1) * (
        D ** 2 / 2 - (5 + 3 * T1 + 10 * C1 - 4 * C1 ** 2 - 9 * ep2) * D ** 4 / 24
        + (61 + 90 * T1 + 298 * C1 + 45 * T1 ** 2 - 252 * ep2 - 3 * C1 ** 2) * D ** 6 / 720)
    lon = (D - (1 + 2 * T1 + C1) * D ** 3 / 6
           + (5 - 2 * C1 + 28 * T1 + 3 * C1 ** 2 + 8 * ep2 + 24 * T1 ** 2) * D ** 5 / 120) / math.cos(phi1)
    return math.degrees(lat), lon0 + math.degrees(lon)


if __name__ == "__main__":
    base = sys.argv[1]  # e.g. .../bnd_sigungu_00_2025_2Q
    rows = read_dbf(base + ".dbf")
    cents = read_shp_centroids(base + ".shp")
    print(",".join(list(rows[0].keys()) + ["lat", "lon"]))
    for r, c in zip(rows, cents):
        lat, lon = tm_inverse(*c)
        print(",".join(list(r.values()) + ["%.5f" % lat, "%.5f" % lon]))
