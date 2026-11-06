"""python3 -I -m unittest discover -s tools/tests"""
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import build_site as bs  # noqa: E402

POLICY_OK = """# 마중 개인정보처리방침

> 작업 메모: 사이트에 나가면 안 되는 내용

시행일: 2026-11-06

첫 문단
이어지는 줄.

## 1. 목록

- **굵게** 항목
- `코드` 항목

## 2. 표

| 대상 | 정보 |
|---|---|
| 지도 <서버> | 접속 기록 |

방침 (https://example.org/privacy), 끝.
"""


def data_json(facilities=None, version="2026-11-04T20:00:00+09:00"):
    return json.dumps({"version": version, "facilities": [{"id": "a"}] if facilities is None else facilities})


class MarkdownTest(unittest.TestCase):
    def test_converts_subset(self):
        title, body = bs.markdown_to_html(POLICY_OK)
        self.assertEqual(title, "마중 개인정보처리방침")
        self.assertIn("<p>첫 문단 이어지는 줄.</p>", body)
        self.assertIn("<li><strong>굵게</strong> 항목</li>", body)
        self.assertIn("<li><code>코드</code> 항목</li>", body)
        self.assertIn("<th>대상</th>", body)
        self.assertIn("<td>지도 &lt;서버&gt;</td>", body, "HTML은 이스케이프한다")
        self.assertIn('<a href="https://example.org/privacy">https://example.org/privacy</a>), 끝.', body)

    def test_work_notes_are_not_published(self):
        _, body = bs.markdown_to_html(POLICY_OK)
        self.assertNotIn("작업 메모", body)

    def test_title_required(self):
        with self.assertRaises(ValueError):
            bs.markdown_to_html("본문만")


class CheckTest(unittest.TestCase):
    def test_policy_rejects_draft_and_missing_date(self):
        bs.check_policy(POLICY_OK)
        with self.assertRaises(ValueError):
            bs.check_policy(POLICY_OK.replace("개인정보처리방침", "개인정보처리방침 (초안)", 1))
        with self.assertRaises(ValueError):
            bs.check_policy(POLICY_OK.replace("2026-11-06", "(출시일)"))

    def test_data_rejects_empty_or_unversioned(self):
        bs.check_data(data_json())
        with self.assertRaises(ValueError):
            bs.check_data(data_json(facilities=[]))
        with self.assertRaises(ValueError):
            bs.check_data(data_json(version=""))
        with self.assertRaises(ValueError):
            bs.check_data("<html>")


class BuildTest(unittest.TestCase):
    def test_build_writes_site(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            policy = tmp / "policy.md"
            policy.write_text(POLICY_OK, encoding="utf-8")
            data = tmp / "facilities.json"
            data.write_text(data_json(), encoding="utf-8")
            out = tmp / "site"
            (out / "old").mkdir(parents=True)  # 예전 결과는 지운다

            bs.build(out, policy=policy, data=data)

            self.assertEqual(sorted(p.name for p in out.iterdir()), [".nojekyll", "data", "index.html", "privacy.html"])
            self.assertEqual((out / "data/facilities.json").read_text(encoding="utf-8"), data_json())
            privacy = (out / "privacy.html").read_text(encoding="utf-8")
            self.assertIn('<html lang="ko">', privacy)
            self.assertIn("<h1>마중 개인정보처리방침</h1>", privacy)
            self.assertIn('href="privacy.html"', (out / "index.html").read_text(encoding="utf-8"))

    def test_build_fails_without_writing_on_bad_data(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            policy = tmp / "policy.md"
            policy.write_text(POLICY_OK, encoding="utf-8")
            data = tmp / "facilities.json"
            data.write_text(data_json(facilities=[]), encoding="utf-8")
            with self.assertRaises(ValueError):
                bs.build(tmp / "site", policy=policy, data=data)
            self.assertFalse((tmp / "site").exists())

    def test_real_repo_files_build(self):
        """저장소의 실제 개인정보처리방침·시설 데이터로 사이트가 만들어진다."""
        with tempfile.TemporaryDirectory() as tmp:
            bs.build(Path(tmp) / "site")
            privacy = (Path(tmp) / "site/privacy.html").read_text(encoding="utf-8")
            self.assertIn(bs.CONTACT, privacy)
            self.assertIn("시행일: 2026-11-06", privacy)


if __name__ == "__main__":
    unittest.main()
