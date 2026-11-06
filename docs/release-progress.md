# 출시 진행 상황

> 마지막 갱신: **2026-11-06**. 다음 세션은 이 문서부터 읽고 시작한다.
> 결정의 근거는 `docs/decisions.md`, Play 요건은 `docs/policy/play-store.md`에 있다.

## 0. 지금 어디까지 왔나 (한눈에)

```
[x] 개발자 계정(개인) 승인 → [x] 앱 생성 → [x] 내부 테스트(0.1.0, 0.1.1) → [x] 앱 설정 11개 완료
→ [ ] 비공개 테스트 시작 (← 지금 여기: 테스터 모집 중)
→ [ ] 12명 이상 × 14일 연속 → [ ] 프로덕션 액세스 신청 → [ ] 정식 출시
```

- **Play Console**: 앱 "마중 - 무료급식·쉼터 지도"(`kr.or.majung.app`). 대시보드의 "앱 설정 완료" 11개를 모두 마쳐 **비공개 테스트 자물쇠가 풀린 상태**(2026-11-06). 앱 검토 전이라 테스터에게는 앱 이름이 `kr.or.majung.app (unreviewed)`로 보인다.
- **최신 업로드**: 내부 테스트에 `0.1.1 (버전 코드 2)`. 사용자가 폰에 설치해 개인정보처리방침 버튼·안내 문구·새로고침 확인(2026-11-06). **다음 업로드는 버전 코드 3 이상** (`app/pubspec.yaml`의 `version:`).
- **저장소**: 모든 작업이 `main`에 커밋·푸시됨(마지막 `5d1e0d2`). 이 문서 갱신만 따로 커밋 여부 확인.
- **테스트**(2026-11-06): 앱 `flutter test` 182개 통과, `pipeline`·`tools/tests`(14개) 통과, 스크린샷 통합 테스트 통과. `flutter analyze`는 예전부터 있던 info 3개뿐.
- 커밋·병합·푸시는 사용자가 요청할 때만 한다.

## 1. 다음에 할 일

### 1-1. 사용자가 할 일: 테스터 모집 (가장 오래 걸림)
- **12명 이상이 옵트인한 상태로 14일 연속** 유지해야 프로덕션을 신청할 수 있다. 중간 이탈 대비 **15명 정도** 모으기.
- 테스터는 Gmail(Google 계정)이 있어야 하고, 참여 링크에서 "테스터 되기" → Play에서 설치 → **14일 동안 지우지 않기**. 프로덕션 신청 때 테스트 중 받은 의견을 묻는 질문이 있으니 실제로 써 보고 의견을 달라고 부탁한다.
- 권장 대상: 지원기관 실무자, 쪽방상담소, 자원봉사자, 지인.
- Claude가 도울 수 있는 것: **테스터 모집 안내문**(테스터가 할 일을 쉬운 말로) 작성 — 지난 세션에서 제안만 하고 아직 안 씀.

### 1-2. Play Console: 비공개 테스트 시작 순서 ("비공개 테스트 → 할 일 보기")
1. **국가/지역**: 대한민국
2. **테스터**: 이메일 목록 또는 **Google 그룹**(모집할 때 편함 — 사람들이 링크로 가입). 의견 받을 곳 `majungdev@gmail.com`
3. **새 버전 만들기** → **"라이브러리에서 추가"**로 이미 올린 `2 (0.1.1)` 선택(새로 올릴 필요 없음). 출시 노트는 내부 테스트 것 재사용 가능
4. 왼쪽 메뉴 **게시 개요** → "검토를 위해 변경사항 전송". 첫 검토는 며칠 걸릴 수 있음
5. 검토가 끝나면 테스터 폰의 Play 스토어 앱 페이지에서 **자세한 설명 줄바꿈**이 제대로 보이는지 확인(Console "애셋 리뷰" 미리보기는 줄바꿈 없이 보여 줌)

### 1-3. Claude가 할 수 있는 일 (테스트 기간 중)
1. [ ] 테스터 모집 안내문
2. [ ] 예비 지도 타일 제공자 조사·결정 (decisions #12), 지도 내장 캐시 1GB 한도를 저사양 폰에 맞게 낮추기
3. [ ] 통합 테스트(`integration_test/app_flow_test.dart`) 에뮬레이터에서 실행
4. [ ] README 스크린샷 shot-2(지역 고르기) 다시 찍기 — 9:16에서 창이 열리는 중에 찍혀 예전 사진 유지 중. 촬영 스크립트에서 창이 다 열릴 때까지 기다리게 할 것
5. [ ] 출시 직전 Play 정책(targetSdk, 테스터 조건) 공식 문서로 다시 확인하고 날짜 갱신

### 확인 필요(작은 것, 사용자에게 아직 안 물음)
- 위치 시트(기준 위치 고르기)에 닫기 버튼이 없다. 글자가 크거나 화면이 짧으면(9:16) 창이 화면을 거의 덮어 뒤로 버튼으로만 닫힌다 — 고칠지 물어볼 것.
- 첫 화면 아이콘이 작아서 "마중" 글자가 이름과 겹쳐 보인다. 어색하면 하트 핀만 잘라 쓰는 안으로 바꾸기로 함.
- 에뮬레이터의 예전 `kr.majung.app.dev` 앱은 지울 것.

## 2. Play Console에 입력한 값 (2026-11-06)

| 항목 | 값 | 근거 |
|---|---|---|
| 앱 이름·기본 언어·유료 여부 | 마중 - 무료급식·쉼터 지도 / ko-KR / 무료 | decisions #4 |
| 개인정보처리방침 | `https://greygitrepo.github.io/majung/privacy.html` | decisions #9 |
| 데이터 보안 | **대략적인 위치만 수집**(선택 사항, 앱 기능, 공유 없음, 임시 처리 아님), 전송 중 암호화 예, 계정 없음, 삭제 요청 아니요 | decisions #22, `docs/policy/data-safety-checklist.md` |
| 로그인·광고·정부 앱·금융·건강 | 로그인 없음 / 광고 없음 / 아니요 / 없음 / 없음 | |
| 타깃층 | 18세 이상 | 가족 정책 심사 피함 |
| 카테고리·연락처 | 지도/내비게이션, `majungdev@gmail.com`, 전화번호 비움(개인 계정이라 공개됨) | |
| 스토어 등록정보 | `docs/store/listing-ko.md`, 아이콘 `docs/store/icon-512.png`, 그래픽 `docs/store/feature-graphic.png`, 스크린샷 `docs/store/screenshots/phone-1~7` | |
| AI 애셋 선언 | 아이콘·그래픽 이미지에 AI 라벨(아이콘이 AI로 만든 것) | 사용자 판단 |
| 외부 마케팅 | 켜 둠(기본값) | |
| 내부 테스트 테스터 | 목록 "나의이메일"(majungdev@gmail.com) | |

## 3. 2026-11-06에 한 일

- **GitHub Pages 공개**: `https://greygitrepo.github.io/majung/` — `privacy.html`, `data/facilities.json`. 주소에 개인 아이디가 보이지만 간편함을 택함(decisions #9). `.github/workflows/pages.yml`이 `main`에서 개인정보처리방침·시설 데이터가 바뀌면 자동 배포(`tools/build_site.py`가 초안·시행일·빈 데이터면 멈춤). 실제 주소에서 200, gzip 약 176KB, ETag → 304 확인.
  - Pages 설정은 **greygitrepo 계정(웹)에서만** 바꿀 수 있다. 이 PC의 `gh`는 `Navifra-Grey`(쓰기 권한만, push는 됨).
- **데이터 요금**: 앱이 화면에 돌아올 때마다 시설 데이터 전체를 받던 것을 ETag(`If-None-Match`)로 바꿔, 바뀐 게 없으면 304로 끝남. 같은 버전도 ETag와 함께 저장해 다음부터 304.
- **앱 설정**: `dataUrl`·`privacyPolicyUrl` 넣음, 앱 정보에 개인정보처리방침 버튼, 개인정보 설명에 "지도를 볼 때는 … 보고 있는 동네가 지도 서버에 전해져요" 추가. 개인정보처리방침 시행일 2026-11-06.
- **데이터 보안 답안**: 지도 타일 요청이 내 위치 근처를 드러낼 수 있어 "대략적인 위치" 수집으로 선언(덜 선언하는 위험 대신 더 선언, decisions #22).
- **스토어 등록정보**: 설명(`tools/check_listing.py`로 글자 수·과장/정부 표현 검사), 그래픽 이미지(`tools/feature_graphic.py`), 스크린샷을 9:16으로 다시 찍음(`tools/store_screenshots.py`). Play는 긴 쪽이 짧은 쪽의 2배를 넘는 스크린샷(예전 1080×2340)을 받지 않는다.
- **앱 버전** `0.1.1+2` 내부 테스트 업로드.

## 4. 이전에 끝낸 것 (요약)

- 2026-11-05: 저장한 곳(decisions #20), 카드 정보 순서(#21), 새 아이콘, 출시 결정 7가지(패키지명 #3, 운영자 #8, 개인 계정 #6, 위치정보법 신고 제외 #11, OSM 타일 #12, 전화 확인 담당 없음 #7 등).
- 릴리스 서명: Gradle이 저장소 밖 `~/.majung-keys/key.properties`로 업로드 키 서명, 키 없으면 `bundleRelease` 멈춤. 업로드 키 생성·백업 완료(2026-11-05).
- 크기: Play 다운로드 약 9MB(내부 테스트 화면 9.05MB), `--split-debug-info` 기본 적용.
- targetSdk 36, minSdk 24, 16KB 페이지 정렬 통과, 권한은 인터넷·위치(대략/정밀)뿐, 백그라운드 위치 없음. Flutter·플러그인을 올리면 다시 확인.

## 5. 자주 쓰는 명령

```bash
docker compose run --rm -w /workspace/app dev flutter test        # 앱 테스트
python3 -I -m unittest discover -s pipeline/tests                  # 파이프라인 테스트
python3 -I -m unittest discover -s tools/tests                     # 사이트·스토어 도구 테스트
python3 -I tools/build_site.py                                     # 사이트 미리 만들기 (build/site)
python3 -I tools/check_listing.py                                  # 스토어 설명 글자 수·금지 표현 검사
python3 -I tools/feature_graphic.py                                # 그래픽 이미지 다시 만들기
python3 -I tools/store_screenshots.py                              # 스토어 스크린샷 만들기 (docs/screenshots에서)
docker compose run --rm emulator-gui                               # PC 화면 에뮬레이터 (r/R/q)
docker compose run --rm release                                    # Play 업로드용 .aab (업로드 키 필요, 버전 코드 올리기)
tools/make_upload_key.sh                                           # 업로드 키 만들기 (한 번만, 내 터미널에서)
python3 -I tools/launcher_icon.py                                  # 아이콘 다시 만들기 (런처 PNG 바이트가 바뀌면 되돌릴 것)
# 스크린샷 다시 찍기 (9:16): app/integration_test/screenshots_test.dart 맨 위 명령
```
