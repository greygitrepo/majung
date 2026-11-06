# 출시 진행 상황

> 마지막 갱신: **2026-11-06**. 다음 세션은 이 문서부터 읽고 시작한다.
> 결정의 근거는 `docs/decisions.md`, Play 요건은 `docs/policy/play-store.md`에 있다.

## 0. 지금 저장소 상태

- 2026-11-05 작업은 모두 커밋해서 **`main`에 병합하고 푸시했다** (`feature/favorites`를 빨리 감기로 병합, 두 브랜치가 같은 커밋).
- 다음 작업은 `main`에서 새 브랜치를 만들어 시작한다.
- 이어서 한 릴리스 서명·크기 작업(`feature/release-signing`)도 커밋해 `main`에 병합·푸시했다 (2026-11-05).
- 테스트: 앱 `flutter test` 175개 통과, `pipeline` 단위 테스트 통과 (2026-11-05). `flutter analyze`는 예전부터 있던 info 3개뿐.
- 커밋·병합·푸시는 사용자가 요청할 때만 한다.

## 1. 2026-11-05에 한 일

### 앱 화면
- **저장한 곳**: 첫 화면에는 카테고리 버튼과 같은 크기의 "저장한 곳" 버튼 하나만 둔다("지금 열림 N곳 · 모두 M곳"). 저장한 곳 화면은 밥 먹을 곳 / 잘 곳 / 아플 때 묶음으로 나눈다 (decisions #20).
- **정보 순서**: 목록 카드·저장한 곳 카드·상세 화면 모두 **장소 이름(24) → 지금 상태(19) → 거리·대상** (decisions #21).
- **첫 화면 제목 옆 아이콘**: 예전 등불(코드로 그림) → 새 "마중" 아이콘 이미지(`app/assets/icon/app-mark.png`, 1x~4x). `tools/launcher_icon.py`가 런처 아이콘과 같은 원본에서 만든다.
- 테스트 보강: 글자 200% 테스트가 실제로 긴급 화면까지 여는지, 저장한 곳 화면의 48dp·대비, 묶음 순서, 이름이 상태보다 위·크게, 앱 설정과 개인정보처리방침·gradle 값 일치.

### 출시 결정 (모두 `docs/decisions.md`에 기록)
| # | 항목 | 결정 |
|---|---|---|
| 3 | 패키지명 | **`kr.or.majung.app`** — Android applicationId·namespace, iOS 번들 ID 모두 적용 |
| 8 | 운영자·문의 | **majungdev · majungdev@gmail.com** — `lib/config.dart`, 개인정보처리방침에 반영. 앱의 오류 신고·문의 버튼이 이제 보인다 |
| 6 | 개발자 계정 | **개인 계정** — 스토어에 실명·국가·이메일 공개, 비공개 테스트 12명 × 14일 필요 |
| 11 | 위치정보법 | **신고 제외로 확정** — 위치를 기기 밖으로 보내지 않을 때만 유효 (`data/research/location-law-20261105.md`) |
| 12 | 지도 타일 | **출시도 OSM 표준 타일** + 예비 계획 |
| 7 | 전화 확인 담당 | **담당 없이 출시** — 확인 안 된 곳은 "가기 전에 전화로 확인" |
| — | 임의 결정 4가지 | 브릿지센터: 전국 확대로 결정 불필요 / 따스한채움터 **02-714-3698 유지**(1666 대표번호는 통화료 별도 가능) / 109 유지 / "노숙 중인 분" 유지 |

## 2. 남은 일

### 사용자(개발자)가 직접 할 일
- [x] **Play 개발자 계정 만들기** (개인) — 2026-11-06 승인, Play Console에 앱 생성(이름 "마중 - 무료급식·쉼터 지도", `kr.or.majung.app`, 기본 언어 ko-KR, 무료)
- [x] **내부 테스트** — 2026-11-06 `0.1.0 (1)` 업로드(설치 9.05MB, API 24+, target 36), 테스터 목록 "나의이메일"(majungdev@gmail.com). 사용자가 폰에 설치해 동작 확인. **다음 업로드는 버전 코드 2 이상**
- [ ] **앱 설정 완료**(Play Console 대시보드) — 쉬운 항목(로그인·광고·정부 앱·금융·건강·타깃층 18+·콘텐츠 등급·카테고리)은 사용자가 입력. 개인정보처리방침 주소·데이터 보안·스토어 등록정보가 남음. 이걸 끝내야 비공개 테스트가 열린다
- [ ] **비공개 테스터 12명 모집** — 14일 연속 참여 필요라 일정상 가장 오래 걸린다. 지원기관 실무자·쪽방상담소·자원봉사자 권장
- [x] **업로드 키 만들고 백업** — 2026-11-05 생성 완료(백업은 사용자가 확인). 내 터미널에서 `tools/make_upload_key.sh` 실행(비밀번호 입력). `~/.majung-keys/`에 `upload-keystore.jks`와 `key.properties`가 생긴다. 이 폴더와 비밀번호를 다른 곳(USB·클라우드)에 백업
- [ ] **GitHub Pages 켜기** — 주소 `https://greygitrepo.github.io/majung/` 확정(2026-11-06). 사이트·배포 설정은 브랜치 `feature/github-pages`에 준비됨. 남은 것: Pages 켜기(원본 "GitHub Actions") → `main` 병합·푸시 → 주소 열어 확인 → Play Console 개인정보처리방침에 `.../privacy.html` 입력
- [ ] 스토어 설명 초안 검토 (과장 표현·정부 앱처럼 보이는 표현 없는지)
- [x] 개인정보처리방침 **시행일** — 2026-11-06(사이트를 처음 공개한 날)로 넣음

### Claude가 할 수 있는 일 (권장 순서)
1. [x] **릴리스 서명 설정** (2026-11-05, 브랜치 `feature/release-signing`) — Gradle이 저장소 밖 `key.properties`를 읽어 업로드 키로 서명. 키가 없으면 `bundleRelease`가 멈춘다(debug 서명 .aab 업로드 방지). 시험용 키로 `.aab` 빌드·서명자 확인함. 빌드: `docker compose run --rm release`
2. [x] **크기 확인·줄이기** (2026-11-05) — `.aab` 51MB는 모든 휴대폰 종류용 파일과 디버그 기록을 합친 크기다. Play가 휴대폰별로 나눠 보내므로 실제 **다운로드 약 9MB, 설치 약 19MB**(arm64). 대부분 Flutter 엔진(11.7MB, 줄일 수 없음).
   - R8은 Flutter 기본값으로 이미 켜져 있음(classes.dex 484KB). Dart 쪽 `print`·로그 호출 없음.
   - `--split-debug-info`를 release 빌드 기본값으로 넣음: libapp 6.1→5.2MB. 빠진 정보는 `app/build/symbols/`(오류 기록 해석용, 비밀 아님).
   - `--obfuscate`는 0.1MB밖에 안 줄어 넣지 않음. 남은 후보: 제목 글꼴(압축 후 313KB), 시설 데이터(압축 후 170KB) — 지금은 손대지 않음
3. [x] **targetSdk·16KB·권한 확인** (2026-11-05, release 빌드 기준) — 고칠 것 없음
   - targetSdk 36, minSdk 24 (Flutter 기본값)
   - 16KB 페이지: arm64 `.so` 4개 모두 zipalign `-P 16` 통과, ELF LOAD 정렬 16KB 이상
   - 권한: `INTERNET`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, 그리고 androidx 내부용 `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`(사용자에게 묻지 않음). 백그라운드 위치 없음
   - Flutter·플러그인을 올리면 다시 확인
4. [x] **GitHub Pages 준비** (2026-11-06, 브랜치 `feature/github-pages`)
   - `lib/config.dart`에 `dataUrl`·`privacyPolicyUrl` 넣음
   - 데이터 요금: 예전에는 앱을 다시 열 때마다 시설 데이터 전체를 받았다. 이제 ETag(`If-None-Match`)를 보내 바뀐 게 없으면 304로 끝난다. 같은 버전을 받아도 저장해 둬서 다음부터 304
   - `tools/build_site.py`: 개인정보처리방침 md → `privacy.html`(`>` 작업 메모는 빼고), 시설 데이터 복사, 초안·시행일·빈 데이터면 멈춤. 테스트 `tools/tests`
   - `.github/workflows/pages.yml`: `main`에 개인정보처리방침·시설 데이터가 바뀌면 자동 배포
   - 앱 버전 `0.1.1+2` (다음 업로드용)
5. [ ] 예비 지도 타일 제공자 조사·결정 (decisions #12), 지도 내장 캐시 1GB 한도를 저사양 폰에 맞게 낮추기
6. [ ] 데이터 보안 양식 답안 정리 (`docs/policy/data-safety-checklist.md` 새로 작성)
7. [ ] 스토어 설명 초안, README 스크린샷 다시 찍기 (shot-1이 예전 저장한 곳 카드 화면)
8. [ ] 통합 테스트(`integration_test/`) 에뮬레이터에서 실행
9. [ ] 출시 직전 Play 정책(targetSdk, 테스터 조건) 공식 문서로 다시 확인하고 날짜 갱신

### 확인 필요(작은 것)
- 에뮬레이터: 패키지명이 바뀌어 새 앱으로 설치된다. 예전 `kr.majung.app.dev` 앱은 지울 것.
- 위치 시트(기준 위치 고르기)에 닫기 버튼이 없다. 글자가 크면 뒤로 버튼으로만 닫힌다 — 고칠지 사용자에게 아직 묻지 않음.
- 첫 화면 아이콘이 작아서 "마중" 글자가 이름과 겹쳐 보인다. 어색하면 하트 핀만 잘라 쓰는 안으로 바꾸기로 함.

## 3. 자주 쓰는 명령

```bash
docker compose run --rm -w /workspace/app dev flutter test        # 앱 테스트
python3 -I -m unittest discover -s pipeline/tests                  # 파이프라인 테스트
python3 -I -m unittest discover -s tools/tests                     # 사이트 만들기 테스트
python3 -I tools/build_site.py                                     # 사이트 미리 만들기 (build/site)
docker compose run --rm emulator-gui                               # PC 화면 에뮬레이터 (r/R/q)
docker compose run --rm release          # Play 업로드용 .aab (업로드 키 필요)
tools/make_upload_key.sh                                           # 업로드 키 만들기 (한 번만, 내 터미널에서)
python3 -I tools/launcher_icon.py                                  # 아이콘 다시 만들기 (런처 PNG 바이트가 바뀌면 되돌릴 것)
```
