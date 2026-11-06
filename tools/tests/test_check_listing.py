"""python3 -I -m unittest discover -s tools/tests"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import check_listing as cl  # noqa: E402


def listing(name="마중", short="가까운 곳을 찾아요.", full="민간 앱이에요."):
    return f"# t\n\n## 앱 이름 (30자 이내)\n\n```\n{name}\n```\n\n## 간단한 설명 (80자 이내)\n\n```\n{short}\n```\n\n## 자세한 설명 (4000자 이내)\n\n```\n{full}\n```\n"


class CheckListingTest(unittest.TestCase):
    def test_ok(self):
        self.assertEqual(cl.problems(listing()), [])

    def test_length_limits(self):
        errs = cl.problems(listing(name="가" * 31, short="나" * 81))
        self.assertEqual(len(errs), 2)

    def test_forbidden_words(self):
        self.assertTrue(cl.problems(listing(full="실시간으로 알려 드려요")))
        self.assertTrue(cl.problems(listing(full="정부가 만든 앱")))
        self.assertEqual(cl.problems(listing(full="정부나 지자체가 만든 앱이 아니에요.")), [])

    def test_emoji_in_short(self):
        self.assertTrue(cl.problems(listing(short="밥 🍚")))

    def test_missing_section(self):
        self.assertTrue(cl.problems("# 빈 문서"))

    def test_real_listing_passes(self):
        self.assertEqual(cl.problems(cl.LISTING.read_text(encoding="utf-8")), [])


if __name__ == "__main__":
    unittest.main()
