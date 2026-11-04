# 마중 - 무료급식·쉼터 지도

취약계층을 위한 무료급식소·쉼터 지도 (Android, Flutter). 규칙은 `CLAUDE.md`, 결정은 `docs/decisions.md`.

## 폴더

| 폴더 | 내용 |
|---|---|
| `app/` | Flutter 앱 |
| `pipeline/` | 공공데이터 → 앱 데이터 변환 (Python 표준 라이브러리만) |
| `data/raw/` | 내려받은 원본 (날짜별) |
| `data/curated/` | 사람이 검토한 보정·제외 (근거 포함) |
| `data/research/` | 자료조사 결과 |
| `data/build-report.md` | 마지막 데이터 빌드 결과·전화 확인 목록 |
| `docs/policy/` | Play·개인정보·데이터·UX 정책 |

## 개발 환경 (Docker, 호스트 설치 불필요)

```bash
docker compose build dev                                      # 처음 한 번
docker compose run --rm -w /workspace/app dev flutter test    # 단위·위젯 테스트
docker compose run --rm -w /workspace/app dev flutter build apk --debug

# 통합 테스트 (헤드리스 에뮬레이터, KVM 필요)
docker compose build emulator
docker compose run --rm -w /workspace/app emulator bash -c "start-emulator && flutter test integration_test -d emulator-5554"

# USB로 연결한 실제 폰
docker compose run --rm -w /workspace/app device flutter run
```

## 데이터 다시 만들기

```bash
python3 -I pipeline/build.py                       # app/assets/data/facilities.json + data/build-report.md
python3 -m unittest discover -s pipeline/tests     # 파이프라인 테스트
```

원본이 바뀌어 운영 문구가 달라지면 구조화된 운영시간을 버리고 "확인 필요"로 표시하며 보고서에 경고를 남긴다.
