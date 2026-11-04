"""python3 -I -m unittest discover -s pipeline/tests"""
import json
import struct
import sys
import tempfile
import unittest
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import build  # noqa: E402
import extract  # noqa: E402
import geocode  # noqa: E402
import geo  # noqa: E402
import regions as rg  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent.parent
TODAY = date(2026, 11, 4)
ALL = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]


def meal_row(**kw):
    row = {
        "FCLTY_NM": "테스트급식", "RDNMADR": "서울특별시 용산구 테스트로 1", "LNMADR": "",
        "INSTT_NM": "서울특별시 용산구", "PHONE_NUMBER": "02-111-2222", "LATITUDE": "37.55", "LONGITUDE": "126.97",
        "MLSV_DATE": "월+화", "MLSV_TIME": "12:00-13:00", "MLSV_TRGET": "노숙인", "MLSV_PLACE": "실내",
        "REFERENCE_DATE": "2026-09-21", "OPER_CLOSE_DATE": "",
    }
    row.update(kw)
    return row


# 법정동 파일 형식: 법정동코드, 시도명, 시군구명, 읍면동명, 리명, 순번, 생성일자
MOLIT = [
    ["1100000000", "서울특별시", "", "", "", "", ""],
    ["1117000000", "서울특별시", "용산구", "", "", "", ""],
    ["1156000000", "서울특별시", "영등포구", "", "", "", ""],
    ["1200000000", "전남광주통합특별시", "", "", "", "", ""],
    ["1220000000", "전남광주통합특별시", "광산구", "", "", "", ""],
    ["1211000000", "전남광주통합특별시", "목포시", "", "", "", ""],
    ["2800000000", "인천광역시", "", "", "", "", ""],
    ["2812500000", "인천광역시", "제물포구", "", "", "", ""],
    ["2812510100", "인천광역시", "제물포구", "신포동", "", "", ""],
    ["2815500000", "인천광역시", "영종구", "", "", "", ""],
    ["2815510100", "인천광역시", "영종구", "운서동", "", "", ""],
    ["2827500000", "인천광역시", "서해구", "", "", "", ""],
    ["2827510100", "인천광역시", "서해구", "가좌동", "", "", ""],
    ["2829000000", "인천광역시", "검단구", "", "", "", ""],
    ["2829010100", "인천광역시", "검단구", "마전동", "", "", ""],
    ["4100000000", "경기도", "", "", "", "", ""],
    ["4111000000", "경기도", "수원시", "", "", "", ""],
    ["4111100000", "경기도", "수원시장안구", "", "", "", ""],
    ["4159000000", "경기도", "화성시", "", "", "", ""],
    ["4159100000", "경기도", "화성시만세구", "", "", "", ""],
    ["4159125000", "경기도", "화성시만세구", "남양읍", "", "", ""],
    ["4159700000", "경기도", "화성시동탄구", "", "", "", ""],
    ["4159710100", "경기도", "화성시동탄구", "반송동", "", "", ""],
]


def cent(sido, name, lat, lng, approx=""):
    return {"sido": sido, "sigungu": name, "lat": str(lat), "lng": str(lng), "approximate": approx,
            "min_lat": str(lat - 0.1), "min_lng": str(lng - 0.1), "max_lat": str(lat + 0.1), "max_lng": str(lng + 0.1)}


CENTROIDS = [
    cent("서울", "용산구", 37.53, 126.98), cent("서울", "영등포구", 37.52, 126.91),
    cent("전남광주", "광산구", 35.17, 126.75), cent("전남광주", "목포시", 34.80, 126.39),
    cent("인천", "제물포구", 37.466, 126.624, "행정동 묶음"), cent("인천", "영종구", 37.472, 126.469, "행정동 묶음"),
    cent("인천", "서해구", 37.532, 126.654, "행정동 묶음"), cent("인천", "검단구", 37.594, 126.649, "행정동 묶음"),
    cent("경기", "수원시 장안구", 37.31, 127.00),
    cent("경기", "화성시 만세구", 37.15, 126.80, "행정동 묶음"), cent("경기", "화성시 동탄구", 37.19, 127.11, "행정동 묶음"),
]


def catalog():
    cat, warnings = rg.build_catalog(MOLIT, CENTROIDS)
    return cat


def ssis_row(kind, sid, name, addr, detail, phone):
    return {"kind": kind, "kind_name": "", "srv_inst_id": sid, "fclt_cd": "", "name": name, "addr": addr,
            "addr_detail": detail, "phone": phone, "jrsd_sgg_cd": ""}


def geo_result(category, typ, lat, lng, display, bbox=None):
    return {"lat": str(lat), "lng": str(lng), "display_name": display, "osm_type": "way", "osm_id": 1,
            "category": category, "type": typ,
            "boundingbox": bbox or [str(lat - 0.0005), str(lat + 0.0005), str(lng - 0.0005), str(lng + 0.0005)]}


GEO_SIDE_STREET = {"query": "부산광역시 부산진구 가야대로587번길 8", "date": "2026-11-04", "results": [
    geo_result("highway", "residential", 35.1555918, 129.0359415, "가야대로587번길, 가야동, 부산진구, 부산광역시, 대한민국",
               ["35.1547823", "35.1564570", "129.0357457", "129.0362446"])]}
GEO_WRONG_NUMBER = {"query": "서울특별시 용산구 한강대로 369", "date": "2026-11-04", "results": [
    geo_result("amenity", "restaurant", 37.5514, 126.9719, "어느식당, 369-1, 한강대로, 동자동, 용산구, 서울특별시, 대한민국"),
    geo_result("highway", "primary", 37.5246, 126.9636, "한강대로, 한강로3가, 용산구, 서울특별시, 대한민국")]}


class GeocodeTest(unittest.TestCase):
    def test_query_and_road(self):
        self.assertEqual(geocode.query_for("부산광역시 부산진구 가야대로587번길 ", "8, 2~3층 (가야동)"),
                         "부산광역시 부산진구 가야대로587번길 8")
        self.assertEqual(geocode.query_for("강원특별자치도 원주시 흥업면 대안로", "1010"), "강원특별자치도 원주시 흥업면 대안로 1010")
        self.assertEqual(geocode.road_name("경기도 의정부시 동일로711번길 41-2"), "동일로711번길")
        self.assertEqual(geocode.house_number("경기도 의정부시 동일로711번길 41-2"), "41-2")

    def test_validate(self):
        cat, _ = rg.build_catalog(MOLIT, CENTROIDS)
        v = geocode.validate
        q = "서울특별시 용산구 테스트로 5"
        def entry(*results, query=q):
            return {"query": query, "date": "2026-11-04", "results": list(results)}
        ok = geo_result("building", "yes", 37.531, 126.979, "5, 테스트로, 용산구, 서울특별시, 대한민국")
        self.assertIsNotNone(v(entry(ok), "서울", "용산구", cat)[0])
        self.assertIsNone(v(None, "서울", "용산구", cat)[0])                                    # 캐시 없음
        self.assertIsNone(v(entry(), "서울", "용산구", cat)[0])                                  # 결과 없음
        far = geo_result("building", "yes", 37.65, 126.98, "5, 테스트로, 용산구, 서울특별시, 대한민국")
        self.assertIn("km", v(entry(far), "서울", "용산구", cat)[1])                             # 시군구에서 10km 넘음
        busan = geo_result("building", "yes", 35.1, 129.0, "5, 테스트로, 부산광역시, 대한민국")
        self.assertIn("시도 범위 밖", v(entry(busan), "서울", "용산구", cat)[1])
        other_road = geo_result("building", "yes", 37.531, 126.979, "5, 다른로, 용산구, 서울특별시, 대한민국")
        self.assertIsNone(v(entry(other_road), "서울", "용산구", cat)[0])                        # 도로명 다름
        self.assertIsNone(v(GEO_WRONG_NUMBER, "서울", "용산구", cat)[0])                          # 369-1 / 큰길 조각
        main_road = geo_result("highway", "primary", 37.531, 126.979, "테스트로, 용산구, 서울특별시, 대한민국")
        self.assertIn("큰길", v(entry(main_road), "서울", "용산구", cat)[1])
        side = "서울특별시 용산구 테스트로12길 3"
        short = geo_result("highway", "residential", 37.531, 126.979, "테스트로12길, 용산구, 서울특별시, 대한민국")
        self.assertIsNotNone(v(entry(short, query=side), "서울", "용산구", cat)[0])
        long_ = geo_result("highway", "residential", 37.531, 126.979, "테스트로12길, 용산구, 서울특별시, 대한민국",
                           ["37.52", "37.54", "126.97", "126.99"])
        self.assertIsNone(v(entry(long_, query=side), "서울", "용산구", cat)[0])                  # 골목길 조각이 너무 김

    def test_real_cache_is_valid_and_offline(self):
        """캐시 파일 형식 + 앱 데이터의 geocoded 시설은 모두 캐시에서 검증을 통과한 좌표."""
        cache = geocode.load_cache(ROOT / "data/curated/geocode-cache.json")
        self.assertTrue(cache)
        for q, e in cache.items():
            self.assertEqual(q, e["query"])
            self.assertRegex(e["date"], r"^\d{4}-\d{2}-\d{2}$")
            for r in e["results"]:
                for k in ("lat", "lng", "display_name", "osm_id"):
                    self.assertIn(k, r)
        dataset, _, report = build.build(ROOT, "x", TODAY)
        self.assertEqual(report.geocode_missing, set())       # 빌드에 필요한 주소가 모두 캐시에 있음
        coords = {(round(float(r["lat"]), 7), round(float(r["lng"]), 7)) for e in cache.values() for r in e["results"]}
        geocoded = [f for f in dataset["facilities"] if f.get("geocoded")]
        self.assertTrue(geocoded)
        for f in geocoded:
            self.assertIn((round(f["lat"], 7), round(f["lng"], 7)), coords, f["name"])
        self.assertIn("osm-nominatim", {s["id"] for s in dataset["sources"]})


class SsisExtractTest(unittest.TestCase):
    XML = ("<?xml version=\"1.0\" encoding=\"UTF-8\"?><response><header><resultCode>00</resultCode>"
           "<resultMsg>SUCCESS</resultMsg></header><body><items><item><fcltCd>E1</fcltCd><fcltNm>테스트센터</fcltNm>"
           "<rprsNm>홍길동</rprsNm><bizno>123</bizno><fcltAddr>서울특별시 용산구 한강대로92길 </fcltAddr>"
           "<fcltDtl_1Addr>6 (갈월동)</fcltDtl_1Addr><fcltTelNo>027775217</fcltTelNo><jrsdSggCd>1117000000</jrsdSggCd>"
           "<fcltKindCd>050107</fcltKindCd><srvInstId>C1</srvInstId></item></items></body></response>")

    def test_parse_drops_personal_fields(self):
        rows = extract.parse_ssis_bass(self.XML.encode("utf-8"))
        self.assertEqual(rows, [{"kind": "050107", "kind_name": "종합지원센터", "srv_inst_id": "C1", "fclt_cd": "E1",
                                 "name": "테스트센터", "addr": "서울특별시 용산구 한강대로92길", "addr_detail": "6 (갈월동)",
                                 "phone": "027775217", "jrsd_sgg_cd": "1117000000"}])
        self.assertNotIn("홍길동", json.dumps(rows, ensure_ascii=False))

    def test_error_response(self):
        bad = self.XML.replace("<resultCode>00", "<resultCode>30")
        with self.assertRaises(ValueError):
            extract.parse_ssis_bass(bad.encode("utf-8"))

    def test_derived_file(self):
        rows = build.read_csv(ROOT / "data/curated/derived/ssis-facilities-20261104.csv")
        kinds = {}
        for r in rows:
            kinds[r["kind"]] = kinds.get(r["kind"], 0) + 1
        self.assertEqual(kinds, {"050107": 13, "050108": 9, "050109": 4, "050110": 1})
        self.assertNotIn("rprs", (ROOT / "data/curated/derived/ssis-facilities-20261104.csv").read_text(encoding="utf-8"))


class SecretTest(unittest.TestCase):
    """SSIS 서비스 키가 data/ 나 app/assets 의 어떤 파일에도 들어가지 않았는지. .env 가 없으면 건너뜀."""

    def test_service_key_not_in_files(self):
        import urllib.parse
        env = ROOT / ".env"
        if not env.exists():
            self.skipTest(".env 없음")
        key = None
        for line in env.read_text(encoding="utf-8").splitlines():
            if line.strip().startswith("SSIS_SERVICE_KEY="):
                key = line.split("=", 1)[1].strip().strip("'\"")
        if not key:
            self.skipTest("SSIS_SERVICE_KEY 없음")
        needles = {key.encode(), urllib.parse.quote(key, safe="").encode(), urllib.parse.quote_plus(key).encode()}
        needles = {n for n in needles if len(n) >= 16}
        leaked = []
        for base in (ROOT / "data", ROOT / "app/assets", ROOT / "pipeline"):
            for path in base.rglob("*"):
                if not path.is_file() or path.is_symlink():
                    continue
                with path.open("rb") as fh:
                    tail = b""
                    while True:
                        chunk = fh.read(1 << 22)
                        if not chunk:
                            break
                        buf = tail + chunk
                        if any(n in buf for n in needles):
                            leaked.append(str(path.relative_to(ROOT)))
                            break
                        tail = buf[-256:]
        self.assertEqual(leaked, [], "서비스 키가 들어 있는 파일 (키 값은 출력하지 않음)")


class NormalizeTest(unittest.TestCase):
    def test_phone(self):
        self.assertEqual(build.normalize_phone("027775217"), "02-777-5217")
        self.assertEqual(build.normalize_phone("0220691600"), "02-2069-1600")
        self.assertEqual(build.normalize_phone("031-123-4567"), "031-123-4567")
        self.assertEqual(build.normalize_phone("16009582"), "1600-9582")
        self.assertIsNone(build.normalize_phone("2672-1004"))  # 지역번호 없음 → 추측하지 않음
        self.assertIsNone(build.normalize_phone(""))
        self.assertIsNone(build.normalize_phone(None))

    def test_clean_phone_rules(self):
        cases = [
            # (원본, 시도, 시군구) → (전화, 확인 필요?)
            (("02-777-5217", "서울", "용산구"), ("02-777-5217", False)),
            (("2672-1004", "서울", "영등포구"), ("02-2672-1004", True)),   # 서울이면 02 를 붙이되 확인 필요
            (("2672-1004", "경기", "수원시 장안구"), (None, True)),         # 경기는 02·031·032 가 섞여 추측 안 함
            (("962-9130", "전남광주", "광산구"), ("062-962-9130", True)),
            (("334-7090", "전남광주", "나주시"), ("061-334-7090", True)),
            (("334-7090", "전남광주", None), (None, True)),
            (("02-1666-7995", "서울", "용산구"), (None, True)),             # 지역번호 + 대표번호 → 오기
            (("02-0475-4585", "서울", "강동구"), (None, True)),             # 불가능한 국번
            (("082-282-8899", "울산", "중구"), (None, True)),
            (("1666-7995", "서울", "용산구"), ("1666-7995", False)),
            (("", "서울", "용산구"), (None, True)),
            (("02-780-5332", "인천", "계양구"), ("02-780-5332", True)),     # 시도와 지역번호가 다름
            (("053-811-0000", "경북", "경산시"), ("053-811-0000", False)),  # 경산은 053
            (("010-1234-5678", "부산", "중구"), ("010-1234-5678", False)),
        ]
        for (raw, sido, sgg), (want, check) in cases:
            with self.subTest(raw=raw, sido=sido):
                phone, issue, need = build.clean_phone(raw, sido, sgg)
                self.assertEqual(phone, want)
                self.assertEqual(need, check, issue)
                if phone:
                    self.assertTrue(build.is_valid_phone(phone))

    def test_eligibility_is_plain_and_non_stigmatizing(self):
        self.assertEqual(build.eligibility_text("노숙인"), "노숙 중인 분")
        self.assertEqual(build.eligibility_text("노숙인+주거취약계층"), "노숙 중인 분, 집이 불안정한 분")
        self.assertEqual(build.eligibility_text("노숙자+어르신"), "노숙 중인 분, 어르신")
        self.assertEqual(build.eligibility_text("노숙자  노인"), "노숙 중인 분 노인")  # 문장 속 노숙자도 바꾸고 공백 정리
        self.assertIsNone(build.eligibility_text(""))

    def test_short_address(self):
        self.assertEqual(build.short_address("서울특별시  용산구 한강대로92길 6 "), "서울 용산구 한강대로92길 6")
        self.assertEqual(build.short_address("광주광역시 광산구 목련로 156(운남동)"), "전남광주 광산구 목련로 156 (운남동)")
        self.assertEqual(build.short_address("전남광주통합특별시 나주시 남고문로 36-14"), "전남광주 나주시 남고문로 36-14")


class SidoTest(unittest.TestCase):
    def test_sixteen_short_names(self):
        self.assertEqual(len(rg.SIDO_ORDER), 16)
        self.assertNotIn("광주", rg.SIDO_ORDER)
        self.assertNotIn("전남", rg.SIDO_ORDER)

    def test_normalize_incl_merger(self):
        cases = {
            "광주광역시 동구 금남로 1": ("전남광주", "동구 금남로 1"),
            "전라남도 해남군 해남읍 해남로 19": ("전남광주", "해남군 해남읍 해남로 19"),
            "전남광주통합특별시 나주시 남고문로 36-14": ("전남광주", "나주시 남고문로 36-14"),
            "광주전남통합특별시 순천시 저전길 84": ("전남광주", "순천시 저전길 84"),
            "충청남도홍성군 광천읍 홍남로 639번길21": ("충남", "홍성군 광천읍 홍남로 639번길21"),
            "강원도 원주시 봉산로 103": ("강원", "원주시 봉산로 103"),
            "전라북도 군산시 문화로 36": ("전북", "군산시 문화로 36"),
            "세종특별자치시 한누리대로 2130": ("세종", "한누리대로 2130"),
            "경기도 광주시 경충대로 1": ("경기", "광주시 경충대로 1"),
            "서울특별시 용산구": ("서울", "용산구"),
        }
        for raw, want in cases.items():
            with self.subTest(raw=raw):
                self.assertEqual(rg.normalize_sido(raw), want)
        self.assertEqual(rg.normalize_sido("제주시 탑동로 2")[0], None)  # 시도 없이 '제주시' → 추측 안 함


class AudienceTest(unittest.TestCase):
    def test_senior_only(self):
        for t in ["65세이상 저소득층", "독거노인+결식노인", "60세이상 기초수급자+차상위계층", "관내 65세 이상 노인",
                  "저소득어르신", "65세이상 경로당 이용어르신", "결식우려노인"]:
            with self.subTest(t=t):
                self.assertEqual(build.classify_audience(t), "senior")

    def test_general(self):
        for t in ["노숙인", "노숙자+어르신", "노인+노숙자", "독거노인+결식노인+노숙인+저소득층", "누구나", "저소득층",
                  "기초수급자+차상위", "장애인", "", None]:
            with self.subTest(t=t):
                self.assertEqual(build.classify_audience(t), "general")

    def test_child_only(self):
        self.assertTrue(build.is_child_only("결식아동"))
        self.assertFalse(build.is_child_only("결식아동+결식노인"))
        self.assertFalse(build.is_child_only("노숙인"))

    def test_stopped(self):
        self.assertTrue(build.is_stopped("임시운영중단"))
        self.assertTrue(build.is_stopped("미운영"))
        self.assertTrue(build.is_stopped("2021년 한시적 사업중단"))
        self.assertFalse(build.is_stopped("월+화+수+목+금(토요일 경로식당 미운영으로 대체식 지급/ 법정 공휴일제외)"))
        self.assertFalse(build.is_stopped("월+화"))


GOOD = {
    "id": "a", "name": "n", "category": "meal", "address": "서울", "lat": 37.5, "lng": 126.9,
    "phone": "02-111-2222", "hours": [{"days": ["mon"], "open": "09:00", "close": "24:00"}],
    "source_id": "s", "last_verified": "2026-01-01", "verified_by": "official", "sido": "서울",
    "sigungu": "용산구", "audience": "general", "cost": "free",
}


class ValidateTest(unittest.TestCase):
    def test_ok(self):
        self.assertEqual(build.validate(GOOD), [])
        self.assertEqual(build.validate({**GOOD, "hours": [], "verified_by": "public_data"}), [])
        self.assertEqual(build.validate({**GOOD, "category": "clinic", "subtype": "health_center"}), [])

    def test_errors(self):
        cases = [
            {"lat": 126.9, "lng": 37.5},
            {"lat": None},
            {"phone": "없음"},
            {"category": "casino"},
            {"last_verified": "어제"},
            {"hours": [{"days": ["monday"], "open": "9", "close": "10:00"}]},
            {"name": " "},
            {"sido": "광주"},
            {"sido": "전라남도"},
            {"sido": None},
            {"audience": "child"},
            {"audience": None},
            {"cost": "paid"},
            {"verified_by": "guess"},
            {"verified_by": "public_data"},          # 공공데이터인데 구조화된 운영시간 (decisions #16)
            {"category": "clinic"},                   # clinic 은 subtype 필수
            {"category": "clinic", "subtype": "spa"},
            {"subtype": "free_clinic"},               # meal 에 subtype
            {"holiday_policy": "sometimes"},
        ]
        for change in cases:
            with self.subTest(change=change):
                self.assertTrue(build.validate({**GOOD, **change}))

    def test_location_warnings(self):
        cat = catalog()
        self.assertEqual(build.location_warnings(GOOD, cat), [])
        self.assertTrue(build.location_warnings({**GOOD, "lat": 35.1, "lng": 129.0}, cat))   # 서울인데 부산 좌표
        self.assertTrue(build.location_warnings({**GOOD, "sigungu": "없는구"}, cat))


class RegionsTest(unittest.TestCase):
    def test_catalog_from_molit(self):
        cat, warnings = rg.build_catalog(MOLIT, CENTROIDS)
        names = [(r.sido, r.sigungu) for r in cat.regions]
        self.assertIn(("인천", "제물포구"), names)
        self.assertIn(("인천", "영종구"), names)
        self.assertIn(("인천", "검단구"), names)
        self.assertIn(("인천", "서해구"), names)          # 법정동·HIRA 이름 그대로
        self.assertNotIn(("인천", "서구"), names)
        self.assertIn(("경기", "화성시 만세구"), names)
        self.assertIn(("경기", "화성시 동탄구"), names)
        self.assertNotIn(("경기", "화성시"), names)       # 일반구가 있는 시는 구 단위로만
        self.assertNotIn(("경기", "수원시"), names)
        self.assertIn(("경기", "수원시 장안구"), names)
        self.assertIn(("전남광주", "광산구"), names)
        codes = [r.code for r in cat.regions]
        self.assertEqual(codes, sorted(codes))
        self.assertEqual(len(codes), len(set(codes)))
        self.assertTrue(any("근사값" in w and "제물포구" in w for w in warnings))

    def test_missing_centroid_is_reported(self):
        cat, warnings = rg.build_catalog(MOLIT, [c for c in CENTROIDS if c["sigungu"] != "영종구"])
        self.assertFalse(cat.has("인천", "영종구"))
        self.assertTrue(any("영종구" in w for w in warnings))

    def test_resolve_new_districts(self):
        cat = catalog()
        r = cat.resolve_sigungu
        self.assertEqual(r("인천", "중구 운서동 123", ["운서동"]), ("영종구", None))
        self.assertEqual(r("인천", "중구 신포로 1 (신포동)", ["신포동"]), ("제물포구", None))
        self.assertEqual(r("인천", "동구 송림로 1"), ("제물포구", None))                 # 옛 동구 → 제물포구
        self.assertEqual(r("인천", "서구 마전로 1 (마전동)", ["마전동"]), ("검단구", None))
        self.assertEqual(r("인천", "서구 가좌로 1 (가좌동)", ["가좌동"]), ("서해구", None))
        self.assertEqual(r("인천", "서해구 가좌로 1"), ("서해구", None))                   # 새 이름으로 적힌 주소
        self.assertEqual(r("경기", "화성시 남양읍 시청로 155", ["남양읍"]), ("화성시 만세구", None))
        self.assertEqual(r("경기", "화성시 동탄구 동탄대로 1"), ("화성시 동탄구", None))
        self.assertEqual(r("경기", "화성시동탄구 동탄대로 1"), ("화성시 동탄구", None))
        sgg, warn = r("경기", "화성시 동탄대로8길 36", [], 37.20, 127.10)                 # 읍면동 없음 → 좌표
        self.assertEqual(sgg, "화성시 동탄구")
        self.assertIn("좌표", warn)
        self.assertEqual(r("전남광주", "광산구 목련로 156"), ("광산구", None))
        self.assertEqual(r("경기", "수원시 장안구 정자로 1"), ("수원시 장안구", None))
        self.assertIsNone(r("서울", "강남구 테헤란로 1")[0])

    def test_area_codes(self):
        self.assertEqual(rg.area_code_for("서울", None), "02")
        self.assertIsNone(rg.area_code_for("경기", "수원시 장안구"))
        self.assertEqual(rg.area_code_for("전남광주", "광산구"), "062")
        self.assertEqual(rg.area_code_for("전남광주", "목포시"), "061")
        self.assertEqual(rg.area_code_for("대구", "군위군"), "054")


class GeoTest(unittest.TestCase):
    def test_tm_round_trip(self):
        for lat, lng in [(37.5665, 126.9780), (35.1796, 129.0756), (33.4996, 126.5312), (38.2, 128.6)]:
            x, y = geo.tm_forward(lat, lng)
            lat2, lng2 = geo.tm_inverse(x, y)
            self.assertAlmostEqual(lat, lat2, places=6)
            self.assertAlmostEqual(lng, lng2, places=6)
        x, y = geo.tm_forward(38.0, 127.5)  # 원점
        self.assertAlmostEqual(x, 1000000.0, places=3)
        self.assertAlmostEqual(y, 2000000.0, places=3)

    def test_area_centroid_and_holes(self):
        square = [[(0, 0), (0, 10), (10, 10), (10, 0), (0, 0)]]          # 시계방향(SHP 바깥 링)
        a, cx, cy = geo.rings_area_centroid(square)
        self.assertEqual((a, cx, cy), (100.0, 5.0, 5.0))
        hole = [(0, 0), (5, 0), (5, 5), (0, 5), (0, 0)]                     # 반시계(구멍), 왼쪽 아래 1/4
        a, cx, cy = geo.rings_area_centroid(square + [hole])
        self.assertAlmostEqual(a, 75.0)
        self.assertGreater(cx, 5.0)
        self.assertTrue(geo.point_in_rings(7, 7, square + [hole]))
        self.assertFalse(geo.point_in_rings(2, 2, square + [hole]))
        self.assertFalse(geo.point_in_rings(11, 5, square))
        self.assertEqual(geo.weighted_centroid([(1, 0, 0), (3, 4, 4)]), (4, 3.0, 3.0))

    def test_read_shp_and_dbf(self):
        ring = [(0.0, 0.0), (0.0, 4.0), (4.0, 4.0), (4.0, 0.0), (0.0, 0.0)]
        content = struct.pack("<i", 5) + struct.pack("<4d", 0, 0, 4, 4) + struct.pack("<ii", 1, len(ring))
        content += struct.pack("<i", 0) + b"".join(struct.pack("<2d", *p) for p in ring)
        rec = struct.pack(">ii", 1, len(content) // 2) + content
        header = struct.pack(">i", 9994) + b"\0" * 20 + struct.pack(">i", (100 + len(rec)) // 2)
        header += struct.pack("<ii", 1000, 5) + b"\0" * 64
        name = "테스트".encode("utf-8")
        dbf = bytearray(32)
        dbf[0] = 3
        dbf[4:8] = struct.pack("<I", 1)
        dbf[8:12] = struct.pack("<HH", 32 + 32 + 1, 1 + 12)
        field = bytearray(32)
        field[0:6] = b"ADM_NM"
        field[11:12] = b"C"
        field[16] = 12
        dbf += field + b"\r" + b" " + name.ljust(12, b" ")
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / "t.shp").write_bytes(header + rec)
            (Path(d) / "t.dbf").write_bytes(bytes(dbf))
            polys = geo.read_shp_polygons(Path(d) / "t.shp")
            self.assertEqual(polys[0][0], ring)
            self.assertEqual(geo.read_dbf(Path(d) / "t.dbf"), [{"ADM_NM": "테스트"}])

    def test_assign_dongs(self):
        def dong(name, x0, cands, old="23010"):
            rings = [[(x0, 0), (x0, 10), (x0 + 10, 10), (x0 + 10, 0), (x0, 0)]]
            a, cx, cy = geo.rings_area_centroid(rings)
            return {"code": name, "name": name, "old": old, "sido": "인천", "candidates": cands, "rings": rings,
                    "bbox": geo.bbox(rings), "area": a, "cx": cx, "cy": cy}
        ds = [dong("A동", 0, ["제물포구", "영종구"]), dong("B동", 10, ["제물포구", "영종구"]),
              dong("운서동", 100, ["제물포구", "영종구"]), dong("C동", 20, ["제물포구", "영종구"]),
              dong("송림동", 50, ["제물포구"], "23020")]
        pts = [("제물포구", 5, 5), ("제물포구", 6, 6), ("영종구", 7, 7), ("영종구", 15, 5)]
        extract.assign_dongs(ds, pts, {("인천", "영종구"): {"운서동"}})
        got = {d["name"]: (d["district"], d["how"].split(" ")[0]) for d in ds}
        self.assertEqual(got["A동"], ("제물포구", "HIRA"))      # 다수결 2:1
        self.assertEqual(got["B동"], ("영종구", "HIRA"))
        self.assertEqual(got["운서동"], ("영종구", "법정동"))
        self.assertEqual(got["C동"][1], "이웃")                  # 가장 가까운 B동을 따름
        self.assertEqual(got["C동"][0], "영종구")
        self.assertEqual(got["송림동"], ("제물포구", "유일"))


class BuildMealsTest(unittest.TestCase):
    def run_build(self, rows, overrides=(), today=TODAY):
        report = build.Report()
        out = build.build_meals(rows, [json.loads(json.dumps(o)) for o in overrides], catalog(), today, report)
        return out, report

    def test_public_data_has_no_structured_hours(self):
        out, _ = self.run_build([meal_row()])
        self.assertEqual(len(out), 1)
        f = out[0]
        self.assertEqual(f["hours"], [])
        self.assertEqual(f["hours_note"], "공공데이터 안내: 월+화 12:00-13:00")
        self.assertEqual(f["verified_by"], "public_data")
        self.assertEqual((f["sido"], f["sigungu"], f["audience"]), ("서울", "용산구", "general"))
        self.assertEqual(f["eligibility"], "노숙 중인 분")
        self.assertEqual(f["last_verified"], "2026-09-21")
        self.assertEqual(build.validate(f), [])

    def test_drop_rules(self):
        rows = [
            meal_row(FCLTY_NM="종료", OPER_CLOSE_DATE="2026-11-03"),
            meal_row(FCLTY_NM="오래됨", REFERENCE_DATE="2025-11-03"),
            meal_row(FCLTY_NM="좌표없음", LATITUDE=""),
            meal_row(FCLTY_NM="중단", MLSV_DATE="임시운영중단"),
            meal_row(FCLTY_NM="미운영", MLSV_DATE="미운영"),
            meal_row(FCLTY_NM="아동", MLSV_TRGET="결식아동"),
            meal_row(FCLTY_NM="주소없음", RDNMADR="", LNMADR=""),
            meal_row(FCLTY_NM="살아있음", OPER_CLOSE_DATE="2026-12-31", REFERENCE_DATE="2025-11-04"),
        ]
        out, report = self.run_build(rows)
        self.assertEqual([f["name"] for f in out], ["살아있음"])
        self.assertEqual(sum(report.drops.values()), 7)
        self.assertEqual(report.drops["운영종료일 지남"], 1)
        self.assertEqual(report.drops["아동 전용(지역아동센터 등)"], 1)

    def test_today_is_injected(self):
        row = meal_row(OPER_CLOSE_DATE="2026-11-10")
        self.assertEqual(len(self.run_build([row], today=date(2026, 11, 4))[0]), 1)
        self.assertEqual(len(self.run_build([row], today=date(2026, 11, 11))[0]), 0)

    def test_senior_audience(self):
        out, _ = self.run_build([meal_row(MLSV_TRGET="65세이상 저소득층")])
        self.assertEqual(out[0]["audience"], "senior")

    def test_old_gwangju_rows_are_duplicates(self):
        rows = [
            meal_row(FCLTY_NM="더불어락노인복지관", RDNMADR="광주광역시 광산구 목련로 156(운남동)", LATITUDE="",
                     REFERENCE_DATE="2025-06-02"),
            meal_row(FCLTY_NM="더불어락노인복지관", RDNMADR="광주광역시 광산구 목련로 156(운남동)", LATITUDE="",
                     REFERENCE_DATE="2025-06-02"),
            meal_row(FCLTY_NM="더불어락노인복지관", RDNMADR="전남광주통합특별시 광산구 목련로 156",
                     LATITUDE="35.17", LONGITUDE="126.81", REFERENCE_DATE="2026-06-01", PHONE_NUMBER="062-960-3800"),
        ]
        out, report = self.run_build(rows)
        self.assertEqual(len(out), 1)
        self.assertEqual(out[0]["sido"], "전남광주")
        self.assertEqual(out[0]["sigungu"], "광산구")
        self.assertEqual(out[0]["last_verified"], "2026-06-01")
        self.assertEqual(report.drops["중복(같은 시도·이름·주소)"], 2)

    def test_same_place_many_schedules_merged(self):
        rows = [meal_row(FCLTY_NM="정나눔터", MLSV_DATE="목", MLSV_TIME="중식(12:00~13:00)"),
                meal_row(FCLTY_NM="정나눔터", MLSV_DATE="토", MLSV_TIME="중식(11:30~12:30)")]
        out, _ = self.run_build(rows)
        self.assertEqual(len(out), 1)
        self.assertIn("목 중식(12:00~13:00)", out[0]["hours_note"])
        self.assertIn("토 중식(11:30~12:30)", out[0]["hours_note"])

    def test_override_application(self):
        ov = [{
            "match": {"sido": "서울", "name": "테스트급식"}, "id": "meal-test",
            "expect_raw": {"MLSV_TIME": "12:00-13:00"},
            "set": {"hours": [{"days": ALL, "open": "12:10", "close": "13:00"}], "verified_by": "official",
                    "last_verified": "2026-11-04", "source_url": "https://example.org", "phone": "02-714-3698"},
            "sources": ["https://example.org"], "reason": "공식", "checked": "2026-11-04",
        }, {"match": {"sido": "서울", "name": "빼기"}, "exclude": "임시중단"},
           {"match": {"sido": "부산", "name": "없는곳"}, "set": {}}]
        out, report = self.run_build([meal_row(), meal_row(FCLTY_NM="빼기")], ov)
        self.assertEqual(len(out), 1)
        f = out[0]
        self.assertEqual(f["id"], "meal-test")
        self.assertEqual(f["hours"][0]["open"], "12:10")
        self.assertEqual(f["verified_by"], "official")
        self.assertEqual(f["phone"], "02-714-3698")
        self.assertEqual(build.validate(f), [])
        self.assertEqual(report.drops["보정: 제외"], 1)
        self.assertTrue(any("없는곳" in w for w in report.warnings))
        self.assertTrue(any("전화번호 보정" in t for t in report.to_verify))
        # 원본 문구가 바뀌면 경고
        _, report2 = self.run_build([meal_row(MLSV_TIME="12:00-14:00")], ov)
        self.assertTrue(any("바뀜" in w for w in report2.warnings))

    def test_override_hours_without_human_check_is_ignored(self):
        ov = [{"match": {"sido": "서울", "name": "테스트급식"},
               "set": {"hours": [{"days": ALL, "open": "12:00", "close": "13:00"}]}}]
        out, report = self.run_build([meal_row()], ov)
        self.assertEqual(out[0]["hours"], [])
        self.assertTrue(any("근거 없는 운영시간" in w for w in report.warnings))

    def test_phone_rules_in_build(self):
        out, report = self.run_build([
            meal_row(FCLTY_NM="가", PHONE_NUMBER="02-1666-7995"),
            meal_row(FCLTY_NM="나", PHONE_NUMBER="2636-3373"),
        ])
        phones = {f["name"]: f.get("phone") for f in out}
        self.assertIsNone(phones["가"])
        self.assertEqual(phones["나"], "02-2636-3373")
        self.assertEqual(len([t for t in report.to_verify if "가" in t or "나" in t]), 2)

    def test_stable_ids(self):
        a, _ = self.run_build([meal_row(), meal_row(FCLTY_NM="다른곳")])
        b, _ = self.run_build([meal_row(FCLTY_NM="다른곳"), meal_row()])
        self.assertEqual(sorted(f["id"] for f in a), sorted(f["id"] for f in b))
        test = next(f for f in a if f["name"] == "테스트급식")
        self.assertEqual(test["id"], build.stable_id("meal", "서울", "테스트급식", "용산구테스트로1"))


class SheltersClinicsTest(unittest.TestCase):
    def busan_catalog(self):
        cat, _ = rg.build_catalog(MOLIT + [["2600000000", "부산광역시", "", "", "", "", ""],
                                           ["2617000000", "부산광역시", "동구", "", "", "", ""],
                                           ["2623000000", "부산광역시", "부산진구", "", "", "", ""]],
                                  CENTROIDS + [cent("부산", "부산진구", 35.16, 129.05), cent("부산", "동구", 35.13, 129.04)])
        return cat

    def test_ssis_shelters(self):
        ssis = [
            ssis_row("050107", "S1", "부산희망등대종합지원센터", "부산광역시 부산진구 가야대로587번길", "8, 2~3층 (가야동)", "0514631127"),
            ssis_row("050107", "S2", "부산희망드림센터", "부산광역시 동구 중앙대로", "404 (좌천동)", "0516319001"),
            ssis_row("050108", "S3", "징검", "부산광역시 부산진구 동천로108번길", "3 (전포동)", "0518070000"),
            ssis_row("050108", "S4", "새시설", "부산광역시 동구 초량중로", "34 (초량동)", "0510000000"),
            ssis_row("050111", "S5", "쪽방상담소", "부산광역시 동구 초량중로", "131", "0514622017"),
        ]
        spec = {"eligibility": "노숙 중인 분", "default_hours_note": "운영시간·입소 방법은 전화로 확인하세요.",
                "entries": [
                    {"ssis": "S1", "id": "shelter-x", "name": "희망등대",
                     "cross_check": [{"source_id": "busan-homeless-fac", "key": {"시설명": "부산희망등대종합지원센터"}}],
                     "hours": [{"days": ALL, "open": "18:00", "close": "07:00"}], "verified_by": "official",
                     "last_verified": "2026-11-04"},
                    {"ssis": "S3", "id": "shelter-y", "name": "징검",
                     "cross_check": [{"source_id": "busan-homeless-fac", "key": {"시설명": "징검"}}],
                     "checks": [{"source": "B", "phone": "051-807-1111"}]},
                    {"ssis": "S9", "id": "shelter-gone", "name": "사라진곳"},
                ],
                "exclude": [{"ssis": "S2", "name": "부산희망드림센터", "reason": "낮 시설"}]}
        raw = {"busan-homeless-fac": ([
            {"시설명": "부산희망등대종합지원센터", "도로명주소": "부산광역시 부산진구 동천로108번길 14(전포동)",
             "전화번호": "051-463-1127", "위도": "35.156339", "경도": "129.062657", "데이터기준일자": "2025-09-30"},
            {"시설명": "징검", "도로명주소": "부산광역시 부산진구 동천로 108번길 3(전포동)", "전화번호": "051-807-0000",
             "위도": "35.158627", "경도": "129.062567", "데이터기준일자": "2025-09-30"},
        ], "2026-11-04")}
        cache = {"부산광역시 부산진구 가야대로587번길 8": GEO_SIDE_STREET}
        report = build.Report()
        out = build.build_shelters(spec, ssis, raw, cache, self.busan_catalog(), report)
        by = {f["id"]: build.compact(f) for f in out}
        self.assertEqual(sorted(by), ["shelter-x", "shelter-y"])        # 드림센터(낮 시설)·쪽방·좌표 없는 새 시설 빠짐
        x, y = by["shelter-x"], by["shelter-y"]
        # 주소가 옛 주소인 원본 좌표는 쓰지 않고, 새 주소를 지오코딩한 좌표를 씀
        self.assertTrue(x["geocoded"])
        self.assertEqual((x["lat"], x["lng"]), (35.1555918, 129.0359415))
        self.assertEqual(x["address"], "부산 부산진구 가야대로587번길 8, 2~3층 (가야동)")
        self.assertEqual(x["hours"][0]["open"], "18:00")
        self.assertEqual(x["source_id"], "ssis-fclt-api")
        # 주소가 같은 원본 좌표는 그대로 (지오코딩 아님)
        self.assertNotIn("geocoded", y)
        self.assertEqual((y["lat"], y["phone"]), (35.158627, "051-807-0000"))
        self.assertEqual((y["hours"], y["verified_by"]), ([], "public_data"))
        self.assertEqual(y["hours_note"], "운영시간·입소 방법은 전화로 확인하세요.")
        for f in by.values():
            self.assertEqual(build.validate(f), [], f["name"])
        self.assertTrue(any("옛 주소" in m for m in report.mismatches))
        self.assertTrue(any("주소 SSIS" in m and "희망등대" in m for m in report.mismatches))
        self.assertTrue(any("전화 SSIS 051-807-0000" in m and "051-807-1111" in m for m in report.mismatches))
        self.assertTrue(any("부산희망드림센터" in e for e in report.excluded))
        self.assertTrue(any("새시설" in n for n in report.need_coords))
        self.assertTrue(any("새 시설" in w for w in report.warnings))
        self.assertTrue(any("사라진곳" in w for w in report.warnings))
        self.assertIn("부산광역시 동구 초량중로 34", report.geocode_missing)

    def test_ssis_meals(self):
        ssis = [ssis_row("050109", "M1", "(사)참좋은친구들", "서울특별시 중구 청파로", "427 (중림동)", "027540031"),
                ssis_row("050109", "M2", "있는곳", "서울특별시 용산구 테스트로", "1", "021112222"),
                ssis_row("050109", "M3", "새급식", "서울특별시 용산구 한강대로", "369 (동자동)", "027070944"),
                ssis_row("050109", "M4", "새급식2", "서울특별시 용산구 한강대로92길", "6", "027775217")]
        spec = {"eligibility": "노숙 중인 분", "hours_note": "운영시간은 공공데이터에 없어요.", "ids": {}, "names": {},
                "exclude": [{"ssis": "M1", "reason": "출처 충돌: 운영종료일 2024-07-26"}]}
        meals = [{"sido": "서울", "address": "서울 용산구 테스트로 1"}]
        cache = {"서울특별시 용산구 한강대로 369": GEO_WRONG_NUMBER,
                 "서울특별시 용산구 한강대로92길 6": {"query": "서울특별시 용산구 한강대로92길 6", "date": "2026-11-04",
                                                "results": [geo_result("building", "yes", 37.5457, 126.9726,
                                                                       "6, 한강대로92길, 갈월동, 용산구, 서울특별시, 대한민국")]}}
        report = build.Report()
        out = [build.compact(f) for f in build.build_ssis_meals(spec, ssis, meals, cache, catalog(), report)]
        self.assertEqual([f["name"] for f in out], ["새급식2"])
        f = out[0]
        self.assertEqual((f["category"], f["audience"], f["hours"], f["geocoded"]), ("meal", "general", [], True))
        self.assertEqual(build.validate(f), [])
        self.assertTrue(any("참좋은친구들" in w and "충돌" in w for w in report.warnings))
        self.assertTrue(any("있는곳" in e for e in report.excluded))
        self.assertTrue(any("새급식" in n and "369-1" in n for n in report.need_coords))

    def test_address_core(self):
        c = build.address_core
        self.assertEqual(c("부산광역시 부산진구 동천로 108번길 14(전포동)"), "동천로108번길14")
        self.assertEqual(c("부산광역시 부산진구 동천로108번길 14"), "동천로108번길14")
        self.assertEqual(c("대구광역시 북구 칠성남로38길22(칠성동2가) 3층"), "칠성남로38길22")
        self.assertEqual(c("대구광역시 북구 칠성남로38길 22 (칠성동2가)"), "칠성남로38길22")
        self.assertNotEqual(c("부산 동구 초량중로 34"), c("부산 동구 중앙대로260번길 3-9"))

    def test_clinics(self):
        spec = {"entries": [
            {"id": "clinic-a", "hira_name": "A의원", "name": "A 무료진료소", "subtype": "free_clinic",
             "verified_by": "official", "last_verified": "2026-11-04",
             "hours": [{"days": ["mon"], "open": "09:00", "close": "17:00"}]},
            {"name": "B", "exclude_reason": "좌표 필요"},
        ], "health_center": {"kinds": ["보건소"], "eligibility": "누구나 (무료 아님, 진료비가 싸요)",
                             "hours_note": "운영시간은 전화로 확인하세요",
                             "exclude": [{"hira_name": "휴진지소", "reason": "일반진료 휴진"}]}}
        hira = [
            {"ykiho": "k1", "name": "A의원", "kind": "의원", "sido": "서울", "address": "서울특별시 용산구 한강대로 1",
             "dong": "", "phone": "02-111-2222", "lng": "126.97", "lat": "37.55"},
            {"ykiho": "k2", "name": "용산구보건소", "kind": "보건소", "sido": "서울", "address": "서울특별시 용산구 녹사평대로 150",
             "dong": "", "phone": "02-2199-8390", "lng": "126.98", "lat": "37.53"},
            {"ykiho": "k4", "name": "휴진지소", "kind": "보건소", "sido": "서울", "address": "서울특별시 용산구 Y",
             "dong": "", "phone": "", "lng": "126.98", "lat": "37.53"},
            {"ykiho": "k3", "name": "어느지소", "kind": "보건지소", "sido": "서울", "address": "서울특별시 용산구 X",
             "dong": "", "phone": "", "lng": "126.98", "lat": "37.53"},
        ]
        report = build.Report()
        out = [build.compact(f) for f in build.build_clinics(spec, hira, catalog(), report)]
        self.assertEqual(len(out), 2)
        hc = next(f for f in out if f["subtype"] == "health_center")
        self.assertEqual(hc["id"], build.stable_id("clinic-hc", "k2"))
        self.assertEqual((hc["cost"], hc["hours"], hc["verified_by"], hc["last_verified"]),
                         ("low_cost", [], "public_data", "2026-09-30"))
        self.assertEqual(hc["eligibility"], "누구나 (무료 아님, 진료비가 싸요)")
        for f in out:
            self.assertEqual(build.validate(f), [], f)
        self.assertTrue(any("B" in n for n in report.need_coords))
        self.assertTrue(any("휴진지소" in e for e in report.excluded))


class RealDataTest(unittest.TestCase):
    """실제 원본 + 보정으로 빌드했을 때의 안전장치."""

    @classmethod
    def setUpClass(cls):
        cls.dataset, cls.regions, cls.report = build.build(ROOT, "2026-11-04T18:00:00+09:00", TODAY)
        cls.fs = cls.dataset["facilities"]
        cls.by_id = {f["id"]: f for f in cls.fs}

    def test_every_facility_valid_and_unique(self):
        ids = [f["id"] for f in self.fs]
        self.assertEqual(len(ids), len(set(ids)))
        for f in self.fs:
            self.assertEqual(build.validate(f), [], f["name"])

    def test_scope(self):
        cats = {f["category"] for f in self.fs}
        self.assertEqual(cats, {"meal", "shelter", "clinic"})
        self.assertEqual({f["sido"] for f in self.fs}, set(rg.SIDO_ORDER))     # 16개 시도 모두
        self.assertEqual({f.get("subtype") for f in self.fs if f["category"] == "clinic"},
                         {"free_clinic", "health_center", "hospital_support"})

    def test_public_data_never_has_hours(self):
        for f in self.fs:
            if f["verified_by"] == "public_data":
                self.assertEqual(f["hours"], [], f["name"])
            if f["category"] == "meal" and f["verified_by"] == "public_data" and f.get("hours_note"):
                self.assertTrue(f["hours_note"].startswith("공공데이터 안내: "), f["name"])

    def test_every_sigungu_in_regions(self):
        keys = {(r["sido"], r["sigungu"]) for r in self.regions}
        for f in self.fs:
            self.assertIn((f["sido"], f.get("sigungu")), keys, f["name"])

    def test_every_source_listed(self):
        listed = {s["id"]: s for s in self.dataset["sources"]}
        for f in self.fs:
            self.assertIn(f["source_id"], listed)
        for s in listed.values():
            self.assertTrue(s.get("license"), s["id"])

    def test_known_corrections(self):
        d = self.by_id["meal-dasiseogi"]
        self.assertEqual(d["verified_by"], "official")
        self.assertEqual([(h["open"], h["close"]) for h in d["hours"]], [("12:10", "13:00"), ("17:50", "18:30")])
        t = self.by_id["meal-ttaseuhan"]
        self.assertTrue(all(h["open"] >= "11:00" for h in t["hours"]))           # 아침 없음
        self.assertEqual(t["phone"], "02-714-3698")
        b = self.by_id["shelter-busan-heemang-deungdae"]
        self.assertEqual((b["hours"][0]["open"], b["hours"][0]["close"]), ("18:00", "07:00"))
        names = " ".join(f["name"] for f in self.fs)
        for gone in ("참좋은친구들", "진여원", "대구희망진료소", "부산희망드림센터", "원곡보건지소"):
            self.assertNotIn(gone, names)
        self.assertEqual(self.by_id["clinic-daegu-medical-center"]["subtype"], "hospital_support")
        self.assertIn("바로", self.by_id["clinic-daegu-medical-center"]["hours_note"])

    def test_ssis_shelters_and_exclusions(self):
        shelters = [f for f in self.fs if f["category"] == "shelter"]
        names = " ".join(f["name"] for f in shelters)
        self.assertNotIn("희망드림", names)
        self.assertNotIn("쪽방", names)
        self.assertNotIn("참좋은친구들", " ".join(f["name"] for f in self.fs))
        self.assertGreaterEqual(len(shelters), 15)
        for f in shelters:
            if f["verified_by"] == "public_data":
                self.assertEqual(f["hours"], [])
                self.assertTrue(f.get("hours_note"))
        hm = self.by_id["clinic-seongnam-medical-center"]
        self.assertEqual(hm["subtype"], "hospital_support")
        self.assertIn("무료 진료소가 아님", hm["eligibility"])
        for f in self.fs:
            if f.get("geocoded"):
                self.assertIs(f["geocoded"], True)
                self.assertTrue(any(f["name"] in g for g in self.report.geocoded), f["name"])

    def test_no_bad_phones(self):
        for f in self.fs:
            if f.get("phone"):
                self.assertFalse(f["phone"].startswith("02-1666"), f["name"])
                self.assertTrue(build.is_valid_phone(f["phone"]), f["name"])

    def test_regions(self):
        keys = {(r["sido"], r["sigungu"]) for r in self.regions}
        for new in [("인천", "제물포구"), ("인천", "영종구"), ("인천", "검단구"), ("인천", "서해구"),
                    ("경기", "화성시 만세구"), ("경기", "화성시 효행구"), ("경기", "화성시 병점구"), ("경기", "화성시 동탄구"),
                    ("전남광주", "광산구"), ("전남광주", "목포시"), ("세종", "세종시"), ("경기", "수원시 장안구")]:
            self.assertIn(new, keys)
        for gone in [("인천", "중구"), ("인천", "동구"), ("인천", "서구"), ("경기", "화성시"), ("경기", "수원시")]:
            self.assertNotIn(gone, keys)
        self.assertEqual({r["sido"] for r in self.regions}, set(rg.SIDO_ORDER))
        codes = [r["code"] for r in self.regions]
        self.assertEqual(codes, sorted(codes))
        self.assertEqual(len(codes), len(set(codes)))
        self.assertLess(len(build.serialize(self.regions)), 30_000)
        for r in self.regions:
            self.assertTrue(33.0 <= r["lat"] <= 38.7 and 124.5 <= r["lng"] <= 132.0, r)

    def test_size(self):
        self.assertLess(len(build.serialize(self.dataset)), build.SIZE_LIMIT)

    def test_no_personal_data(self):
        text = json.dumps(self.dataset, ensure_ascii=False)
        self.assertNotIn("대표자", text)
        self.assertNotIn("OO", text)

    def test_deterministic(self):
        again, regions, _ = build.build(ROOT, "2026-11-04T18:00:00+09:00", TODAY)
        self.assertEqual(build.serialize(again), build.serialize(self.dataset))
        self.assertEqual(build.serialize(regions), build.serialize(self.regions))

    def test_app_assets_match_build(self):
        """앱에 들어간 파일이 지금 원본으로 다시 빌드한 결과와 같은지 (버전 제외)."""
        asset = json.loads((ROOT / "app/assets/data/facilities.json").read_text(encoding="utf-8"))
        self.assertEqual(asset["facilities"], self.dataset["facilities"])
        self.assertEqual(asset["holidays"], self.dataset["holidays"])
        self.assertEqual(asset["sources"], self.dataset["sources"])
        regions = json.loads((ROOT / "app/assets/data/regions.json").read_text(encoding="utf-8"))
        self.assertEqual(regions, self.regions)


if __name__ == "__main__":
    unittest.main()
