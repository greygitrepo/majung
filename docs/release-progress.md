# 출시 진행 상황

> 마지막 갱신: **2026-11-05**. 다음 세션은 이 문서부터 읽고 시작한다.
> 결정의 근거는 `docs/decisions.md`, Play 요건은 `docs/policy/play-store.md`에 있다.

## 0. 지금 저장소 상태

- 2026-11-05 작업은 모두 커밋해서 **`main`에 병합하고 푸시했다** (`feature/favorites`를 빨리 감기로 병합, 두 브랜치가 같은 커밋).
- 다음 작업은 `main`에서 새 브랜치를 만들어 시작한다.
- 2026-11-05 이후 작업: `feature/release-signing` 브랜치(릴리스 서명, 아직 커밋 안 함).
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
- [ ] **Play 개발자 계정 만들기** (개인) — 2026-11-05 가입 완료, **승인 대기 중**
- [ ] **비공개 테스터 12명 모집** — 14일 연속 참여 필요라 일정상 가장 오래 걸린다. 지원기관 실무자·쪽방상담소·자원봉사자 권장
- [x] **업로드 키 만들고 백업** — 2026-11-05 생성 완료(백업은 사용자가 확인). 내 터미널에서 `tools/make_upload_key.sh` 실행(비밀번호 입력). `~/.majung-keys/`에 `upload-keystore.jks`와 `key.properties`가 생긴다. 이 폴더와 비밀번호를 다른 곳(USB·클라우드)에 백업
- [ ] **GitHub Pages 켜기** — 개인정보처리방침 페이지와 시설 데이터 JSON 호스팅 (decisions #9)
- [ ] 스토어 설명 초안 검토 (과장 표현·정부 앱처럼 보이는 표현 없는지)
- [ ] 개인정보처리방침 **시행일** 정하기 (출시일)

### Claude가 할 수 있는 일 (권장 순서)
1. [x] **릴리스 서명 설정** (2026-11-05, 브랜치 `feature/release-signing`) — Gradle이 저장소 밖 `key.properties`를 읽어 업로드 키로 서명. 키가 없으면 `bundleRelease`가 멈춘다(debug 서명 .aab 업로드 방지). 시험용 키로 `.aab` 빌드·서명자 확인함. 빌드: `docker compose run --rm release flutter build appbundle`
   - 참고: 지금 `.aab`가 53.9MB로 크다 → 2번에서 함께 줄일 것
2. [ ] R8 코드 축소, 릴리스 디버그 로그 제거
3. [ ] targetSdk 36, 16KB 페이지 크기, 병합 매니페스트 권한 확인 (`docs/policy/play-store.md` 5절 체크리스트)
4. [ ] `lib/config.dart`에 `dataUrl`, `privacyPolicyUrl` 넣기 (GitHub Pages 주소가 정해지면)
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
docker compose run --rm emulator-gui                               # PC 화면 에뮬레이터 (r/R/q)
docker compose run --rm release flutter build appbundle          # Play 업로드용 .aab (업로드 키 필요)
tools/make_upload_key.sh                                           # 업로드 키 만들기 (한 번만, 내 터미널에서)
python3 -I tools/launcher_icon.py                                  # 아이콘 다시 만들기 (런처 PNG 바이트가 바뀌면 되돌릴 것)
```
