"""python3 -m unittest discover -s pipeline/tests"""
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import build  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent.parent


def meal_row(**kw):
    row = {
        "FCLTY_NM": "테스트급식", "RDNMADR": "서울특별시 용산구 테스트로 1", "LNMADR": "",
        "PHONE_NUMBER": "02-111-2222", "LATITUDE": "37.55", "LONGITUDE": "126.97",
        "MLSV_DATE": "월+화", "MLSV_TIME": "12:00-13:00", "MLSV_TRGET": "노숙인",
        "REFERENCE_DATE": "2026-09-21", "OPER_CLOSE_DATE": "",
    }
    row.update(kw)
    return row


CURATED = {
    "source_id": "src", "target_gu": ["중구", "용산구", "영등포구"],
    "entries": {
        "테스트급식": {
            "id": "meal-test",
            "expect_raw": {"MLSV_DATE": "월+화", "MLSV_TIME": "12:00-13:00"},
            "hours": [{"days": ["mon", "tue"], "open": "12:00", "close": "13:00"}],
        },
        "제외급식": {"exclude": "테스트"},
    },
}


class NormalizeTest(unittest.TestCase):
    def test_phone(self):
        self.assertEqual(build.normalize_phone("027775217"), "02-777-5217")
        self.assertEqual(build.normalize_phone("0220691600"), "02-2069-1600")
        self.assertEqual(build.normalize_phone("031-123-4567"), "031-123-4567")
        self.assertEqual(build.normalize_phone("16009582"), "1600-9582")
        self.assertIsNone(build.normalize_phone("2672-1004"))  # 지역번호 없음 → 추측하지 않음
        self.assertIsNone(build.normalize_phone(""))
        self.assertIsNone(build.normalize_phone(None))

    def test_eligibility_is_plain_and_non_stigmatizing(self):
        self.assertEqual(build.eligibility_text("노숙인"), "노숙 중인 분")
        self.assertEqual(build.eligibility_text("노숙인+주거취약계층"), "노숙 중인 분, 집이 불안정한 분")
        self.assertIsNone(build.eligibility_text(""))

    def test_short_address(self):
        self.assertEqual(build.short_address("서울특별시  용산구 한강대로92길 6 "), "서울 용산구 한강대로92길 6")


class ValidateTest(unittest.TestCase):
    good = {
        "id": "a", "name": "n", "category": "meal", "address": "서울", "lat": 37.5, "lng": 126.9,
        "phone": "02-111-2222", "hours": [{"days": ["mon"], "open": "09:00", "close": "24:00"}],
        "source_id": "s", "last_verified": "2026-01-01",
    }

    def test_ok(self):
        self.assertEqual(build.validate(self.good), [])

    def test_errors(self):
        cases = [
            {"lat": 126.9, "lng": 37.5},
            {"lat": None},
            {"phone": "없음"},
            {"category": "casino"},
            {"last_verified": "어제"},
            {"hours": [{"days": ["monday"], "open": "9", "close": "10:00"}]},
            {"name": " "},
        ]
        for change in cases:
            with self.subTest(change=change):
                self.assertTrue(build.validate({**self.good, **change}))


class BuildMealsTest(unittest.TestCase):
    def run_build(self, rows):
        report = build.Report()
        return build.build_meals(rows, CURATED, report), report

    def test_filters_region_and_structures_hours(self):
        out, report = self.run_build([
            meal_row(),
            meal_row(FCLTY_NM="강남급식", RDNMADR="서울특별시 강남구 테스트로 1"),
            meal_row(FCLTY_NM="경기급식", RDNMADR="경기도 용산구처럼보이는주소"),
        ])
        self.assertEqual([f["id"] for f in out], ["meal-test"])
        self.assertEqual(out[0]["hours"][0]["days"], ["mon", "tue"])
        self.assertEqual(out[0]["eligibility"], "노숙 중인 분")
        self.assertEqual(out[0]["last_verified"], "2026-09-21")

    def test_raw_text_change_drops_structured_hours(self):
        out, report = self.run_build([meal_row(MLSV_TIME="12:00-14:00")])
        self.assertEqual(out[0]["hours"], [])
        self.assertIn("12:00-14:00", out[0]["hours_note"])
        self.assertTrue(any("바뀜" in w for w in report.warnings))

    def test_unknown_facility_is_not_published(self):
        out, report = self.run_build([meal_row(FCLTY_NM="새급식소")])
        self.assertEqual(out, [])
        self.assertTrue(any("새 시설" in w for w in report.warnings))

    def test_closed_or_excluded(self):
        out, report = self.run_build([meal_row(OPER_CLOSE_DATE="2024-07-26"), meal_row(FCLTY_NM="제외급식")])
        self.assertEqual(out, [])
        self.assertEqual(len(report.excluded), 2)

    def test_disappeared_facility_warns(self):
        _, report = self.run_build([])
        self.assertTrue(any("사라짐" in w for w in report.warnings))


class RealDataTest(unittest.TestCase):
    """실제 원본 + 보정으로 빌드했을 때의 안전장치."""

    @classmethod
    def setUpClass(cls):
        cls.dataset, cls.report = build.build(ROOT, "2026-11-03T00:00:00+09:00")

    def test_every_facility_valid_and_unique(self):
        ids = [f["id"] for f in self.dataset["facilities"]]
        self.assertEqual(len(ids), len(set(ids)))
        for f in self.dataset["facilities"]:
            self.assertEqual(build.validate(f), [], f["name"])

    def test_first_release_scope(self):
        cats = {f["category"] for f in self.dataset["facilities"]}
        self.assertLessEqual(cats, {"meal", "shelter"})
        self.assertIn("meal", cats)
        self.assertIn("shelter", cats)

    def test_every_source_listed(self):
        listed = {s["id"] for s in self.dataset["sources"]}
        for f in self.dataset["facilities"]:
            self.assertIn(f["source_id"], listed)

    def test_closed_facility_excluded(self):
        names = [f["name"] for f in self.dataset["facilities"]]
        self.assertNotIn("참좋은친구들", names)

    def test_no_personal_data(self):
        text = json.dumps(self.dataset, ensure_ascii=False)
        self.assertNotIn("대표자", text)
        self.assertNotIn("OO", text)

    def test_app_asset_matches_build(self):
        """앱에 들어간 파일이 지금 원본으로 다시 빌드한 결과와 같은지 (버전 제외)."""
        asset = json.loads((ROOT / "app/assets/data/facilities.json").read_text(encoding="utf-8"))
        self.assertEqual(asset["facilities"], self.dataset["facilities"])
        self.assertEqual(asset["holidays"], self.dataset["holidays"])


if __name__ == "__main__":
    unittest.main()
