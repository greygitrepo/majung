# 지도: flutter_map + OSM 타일 조사 (+ 길찾기 딥링크, Google Play 요건)

> 조사일: **2026-11-03**. 표의 "확인일"은 모두 2026-11-03.
> 배경: 네이버 지도 SDK는 앱에 넣지 않기로 결정. 이 문서가 예전 `naver-maps.md`를 대신한다. 예전 문서에서 남긴 것은 7절(딥링크), 8절(네이버 장소 데이터 재사용), 9절(Google Play)뿐이다.
> 표기: ✅ 공식 출처 2곳 이상 또는 원본(바이너리·약관 원문·API 응답)으로 직접 확인 / ☑️ 공식 출처 1곳 / ⚠️ 2차 출처뿐이거나 출처끼리 어긋남 / ❓ 확인 못 함

---

## 0. 한눈에 보기

| # | 결론 | 절 |
|---|---|---|
| 1 | **flutter_map 8.3.2**(2026-08-27). BSD-3-Clause. 순수 Dart라 자체 네이티브 `.so`가 없어 16KB·minSdk 걱정이 Flutter 엔진 수준으로 줄어든다. 실제 minSdk는 Flutter 3.47 하한인 **API 24**. | 1 |
| 2 | **8.2부터 내장 타일 캐시가 기본으로 켜져 있다**(모바일, 기본 1GB 소프트 한도, HTTP 캐시 헤더를 따름). 다만 "오프라인 보장용이 아니다"라고 공식 문서에 적혀 있다. | 1.2 |
| 3 | `flutter_map_tile_caching`(FMTC)은 **GPL-3.0**이다. 앱 소스를 GPL로 공개하거나 라이선스를 사야 한다. 비영리 단체에는 무료 대체 라이선스를 줄 수 있다고 README에 적혀 있다. | 1.3 |
| 4 | **키·가입 없이 쓸 수 있는 1순위 타일은 OSM 표준 타일(래스터)**이다. 앱 사용은 허용되지만 고유 User-Agent, 캐시 헤더 준수, 표기가 필수다. **오프라인 다운로드와 미리 받기는 금지**이고 SLA가 없으며 예고 없이 차단될 수 있다. → 예비 타일 서버를 준비해야 한다. | 2.1 |
| 5 | **OpenFreeMap**: 무료·무제한·키 없음·상업 이용 가능. 오프라인 다운로드는 1회 3,000타일 또는 50MB까지 허용. 하지만 **벡터 타일만** 제공한다. flutter_map에서 쓰려면 `vector_map_tiles`가 필요한데, 이 패키지는 "최소 유지보수" 상태이고 flutter_map 8과 맞는 버전은 **베타뿐**이다. | 2.2 |
| 6 | 한국어 라벨: 3개 구 OSM 데이터를 Overpass로 받아 셌다. **`name`이 기본적으로 한국어**다(POI 87~97%, 도로·정류장 99~100%, 역 100%에 한글 포함). `name:ko`는 POI의 12~27%에만 있다 → **`name`을 그대로 쓰면 된다**. OSM 표준 타일은 `name`을 그리므로 한국어로 나온다. OpenFreeMap 기본 스타일은 "로마자 + 한글" 2줄로 그려서 스타일 수정이 필요하다. | 3 |
| 7 | OSM에는 복지시설이 거의 없다(요셉의원만 있고 쪽방상담소·급식소는 못 찾음). 시설 데이터는 공공데이터로 따로 올려야 한다(예정대로). | 3.3 |
| 8 | ODbL 표기: 지도 모서리에 "© OpenStreetMap"(또는 "OpenStreetMap contributors")을 넣고 openstreetmap.org/copyright 링크를 단다. 사용자가 조작하지 않아도 보여야 한다. 5초 뒤에 접거나 지도를 만지면 접는 것은 허용되지만, (i) 버튼 같은 곳에서 계속 찾을 수 있어야 한다. → flutter_map `RichAttributionWidget`로 충족 가능. | 4 |
| 9 | 길찾기 버튼: `nmap://route/walk?dlat&dlng&dname&appname` 또는 `kakaomap://route?ep=..&by=foot`. 앱이 없으면 **키 없는 웹 링크 `https://map.kakao.com/link/to/이름,위도,경도`**로 보낸다. targetSdk 30 이상이면 `<queries>`를 선언해야 한다. | 7 |
| 10 | 네이버 장소 정보는 수집·재사용 금지(네이버 이용약관, NCP Maps 약관 7조⑪). | 8 |
| 11 | Play: **targetSdk 36** 필수. 16KB 미지원 업데이트는 **2027-02-01부터 출시 불가**. 개인 계정은 **12명이 14일 연속** 비공개 테스트. | 9 |

---

## 1. flutter_map

### 1.1 기본 정보

| 항목 | 값 | 출처 | 상태 |
|---|---|---|---|
| 최신 안정 버전 | **8.3.2** (2026-08-27). 이전: 8.3.1 2026-06-30, 8.3.0 2026-04-13, 8.2.2 2025-09-19. 프리릴리스 8.4.0-dev.1 (2026-09-02) | pub.dev API https://pub.dev/api/packages/flutter_map , https://pub.dev/packages/flutter_map/versions | ✅ |
| 저장소 활동 | 마지막 push 2026-11-02, archived 아님 | https://github.com/fleaflet/flutter_map (GitHub API) | ✅ |
| 라이선스 | **BSD-3-Clause** | GitHub API license 필드, pub.dev | ✅ |
| Dart / Flutter | Dart `>=3.6.0 <4.0.0`, Flutter `>=3.27.0` | pub.dev API pubspec | ✅ |
| 의존성 | 순수 Dart 패키지(http, latlong2, path_provider, proj4dart, uuid 등). 자체 Android 네이티브 코드 없음 | pub.dev API pubspec `dependencies` | ☑️ (pubspec에 Android 플러그인 선언이 없음을 확인. 공식 문서에 "pure Dart" 문구는 없음) |
| Android minSdk | 패키지가 따로 정하지 않음 → **Flutter 3.47의 지원 하한인 API 24(Android 7.0)**. `path_provider_android` 하한은 확인하지 않음 ❓ | https://docs.flutter.dev/reference/supported-platforms ("Supported 24 to 37") | ☑️ |
| Android 설정 | 릴리스 빌드에 `INTERNET` 권한 필요(이미 `play-store.md`에 있음) | https://docs.fleaflet.dev/getting-started/installation | ☑️ |
| 알려진 주의 | 모바일 렌더링 깨짐은 Impeller 때문일 수 있음 → `--no-enable-impeller`로 테스트하라고 안내 | 같은 문서 | ☑️ |

→ `play-store.md`의 "minSdk 목표 API 24"와 Flutter 하한이 같다. 이보다 더 낮출 수는 없다.

### 1.2 내장 캐시 (8.2부터)

출처: https://docs.fleaflet.dev/layers/tile-layer/built-in-caching , https://docs.fleaflet.dev/tile-servers/using-openstreetmap-direct (두 문서 내용 일치 ✅)

| 항목 | 내용 |
|---|---|
| 기본값 | 웹이 아닌 플랫폼에서 **기본으로 켜짐**(`BuiltInMapCachingProvider`) |
| 저장 위치 | OS 캐시 디렉터리. "운영체제가 언제든 지울 수 있음" |
| 크기 | 기본 **1GB 소프트 한도**. 한도는 프로바이더가 초기화될 때(보통 세션 첫 타일)만 적용 |
| 신선도 | HTTP 캐시 헤더를 따름. `overrideFreshAge`로 기간 강제 가능 |
| OSM 정책 | "OSM 공개 타일 서버의 캐싱 요건을 충족하도록 설계". 끄면 정책 위반이 될 수 있음 |
| 한계 | "캐시된 타일이 없을 때 위험한 상황이 생길 수 있는 곳에는 의존하지 말 것" → 오프라인 전용 솔루션을 쓰라고 안내 |

이 앱 메모:
- 1GB는 저사양 폰에 너무 크다. 한도를 수십 MB 수준으로 낮추는 설정을 검토한다(설정 이름과 단위는 구현 시 API 문서로 확인 ❓).
- CLAUDE.md 규칙 6(오프라인)의 핵심은 **목록·전화번호**다. 지도 타일이 오프라인에서 비어 있어도 앱이 동작하도록 설계한다. 타일 캐시는 덤으로 본다.
- OSM 응답 헤더를 실측했다(2026-11-03, z16 서울 타일 1장): `cache-control: max-age=21425, stale-while-revalidate=604800, stale-if-error=604800`. 내장 캐시가 이 헤더를 따르면 오프라인에서도 최대 약 7일 동안 stale 타일을 쓸 수 있을 것으로 **추정**한다(flutter_map이 stale-if-error를 처리하는지는 확인 못 함 ❓).

### 1.3 오프라인·캐시 플러그인

| 패키지 | 최신 버전 | 라이선스 | flutter_map 호환 | 비고 | 상태 |
|---|---|---|---|---|---|
| `flutter_map_tile_caching` (FMTC) | 10.1.1 (2025-03-09) | **GPL-3.0** | `^8.1.1` | 영역 일괄 다운로드 지원. README: GPL 앱이 아니면 유료 라이선스, "비영리 단체에는 무료 대체 라이선스 제공 가능(*)". **OSM 표준 타일로 일괄 다운로드하는 것은 OSM 정책 위반**(2.1) | ✅ (pub.dev API + GitHub license + README) |
| `flutter_map_cache` | 2.1.1 (2026-10-31) | ❓ 확인 안 함 | `>=6.0.0 <9.0.0` | dio + dio_cache_interceptor 기반 HTTP 캐시. 8.2부터 내장 캐시가 생겨서 우선순위 낮음 | ☑️ |

→ 이 앱은 소스를 공개할지 아직 정하지 않았다. FMTC를 쓰려면 ① 앱을 GPL-3.0으로 공개하거나 ② 운영 비영리 단체 명의로 무료 라이선스를 문의해야 한다. 지금은 **내장 캐시만 쓰는 것을 기본값**으로 둔다.

### 1.4 표기(Attribution) 위젯

출처: https://docs.fleaflet.dev/layers/attribution-layer ☑️

| 위젯 | 특징 |
|---|---|
| `RichAttributionWidget` | 로고는 항상 보이고 텍스트는 아이콘 버튼 팝업으로 연다. 공식 문서: "대부분의 ToS를 기본 설정으로 쉽게 충족하도록 설계" |
| `SimpleAttributionWidget` | 웹 지도식 고정 박스 |
| 직접 구현 | `Align` 등으로 구현 가능 |

flutter_map 문서는 "타일 서버 ToS에 따라 출처를 표기해야 하며, 라이브러리 제작자는 위반에 책임지지 않는다"고 적는다. OSM 예제 텍스트는 "OpenStreetMap contributors" + https://openstreetmap.org/copyright 링크.

---

## 2. 키·가입이 필요 없는 타일 서버

### 2.1 OSM 표준 타일 `tile.openstreetmap.org` (래스터 PNG)

출처: OSMF 타일 사용 정책 https://operations.osmfoundation.org/policies/tiles/ , flutter_map 문서 https://docs.fleaflet.dev/tile-servers/using-openstreetmap-direct (두 출처 내용 일치 ✅)

| 항목 | 내용 |
|---|---|
| URL | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` (HTTPS) |
| 앱 사용 | **금지는 아니다.** 고유하고 안정적인 User-Agent가 필수이고, 라이브러리 기본 UA는 차단된다(정책 3.4) |
| User-Agent | 앱 이름이 들어간 고유 UA. flutter_map에서는 `TileLayer.userAgentPackageName`을 실제 패키지명으로 설정한다. 비워 두거나 `com.example.app`이면 **차단 타일이 돌아온다**(flutter_map 문서) |
| Referer | 네이티브 앱은 없어도 됨 |
| 캐시 | 서버 캐시 헤더 준수. 헤더를 못 읽으면 최소 7일 보관. 기본으로 `Cache-Control: no-cache`를 보내면 금지 |
| 표기 | 지도 위에 OSM 표기(보통 오른쪽 아래) |
| **금지** | 대량 다운로드·미리 받기(prefetch), 타일 아카이브 생성, **오프라인 사용("오프라인용 다운로드" 기능)**, 브라우저·앱 위장 |
| SLA | 없음. best-effort |
| 차단 | 서비스에 부담이 되면 **예고 없이 차단** 가능 |
| 상업·후원 서비스 | 상업 서비스나 후원을 받는 서비스는 "언제든 접근이 철회될 수 있음을 특히 인지해야 한다"(정책 7절) |
| "무거운 사용" | 숫자 기준은 없다. "무겁거나 부적절한 사용은 다른 사람의 편집·열람을 해친다"며 차단 가능하다고만 적혀 있다 |

판단: 1차 지역 3개 구, 사용자 수가 적은 단계에서는 정책을 지키면 쓸 수 있다. 다만 **SLA가 없고 차단될 수 있으므로** 타일 URL을 원격 설정이나 앱 업데이트로 바꿀 수 있게 만들고 예비 서버를 정해 둔다.

### 2.2 OpenFreeMap

출처: https://openfreemap.org/ , ToS https://openfreemap.org/tos/ (최종 수정 **2026-10-14**), Quick Start https://openfreemap.org/quick_start/ ✅

| 항목 | 내용 |
|---|---|
| 비용·한도 | 공개 인스턴스는 무료. "지도 조회·요청 수 제한 없음". 가입·API 키·쿠키 없음 |
| 상업 이용 | 허용 |
| 형식 | **벡터 타일만**(OpenMapTiles 스키마). 스타일: Liberty, Bright, Positron, Dark, Fiord, 3D. 스타일 URL 예: `https://tiles.openfreemap.org/styles/liberty`. 래스터 타일은 언급 없음 |
| 실측 | Liberty 스타일 JSON의 소스는 `openmaptiles: https://tiles.openfreemap.org/planet`, 음영기복 PNG `ne2_shaded`(Natural Earth 래스터 — 지형 음영일 뿐 일반 지도가 아님) |
| 오프라인 | 앱에서 사용자 영역 다운로드 허용: **1회 최대 3,000타일 또는 50MB, 병렬 4개 이하, 고유 User-Agent**. 그보다 크면 info@openfreemap.org에 문의 |
| 금지 | 오프라인 다운로드 외의 자동 수집 |
| 보증 | AS-IS, 업타임 보증 없음, **예고 없이 중단 가능**. 운영비는 기부로 충당 |
| 표기 | "OpenFreeMap © OpenMapTiles Data from OpenStreetMap" (각각 openfreemap.org, openmaptiles.org, openstreetmap.org/copyright 링크). MapLibre가 아닌 클라이언트는 직접 넣어야 함 |

**flutter_map에서 OpenFreeMap(벡터)을 쓰려면** `vector_map_tiles`가 필요하다.

| 항목 | 값 | 출처 | 상태 |
|---|---|---|---|
| 최신 안정 버전 | **8.0.0** (2024-08-16). 요구 `flutter_map ^7.0.2` → **flutter_map 8과 호환 안 됨** | pub.dev API | ✅ |
| flutter_map 8용 | **9.0.0-beta.x**(베타; 최신 9.0.0-beta.13, 2026-09-01, `flutter_map ^8.1.1`), 10.0.0-beta(Flutter main 채널과 flutter_gpu 필요) | pub.dev API | ✅ |
| README 권고 | "프로덕션에는 8.0.0 또는 9.0.0-beta.8을 쓰라". **"vector_map_tiles는 최소한으로만 유지보수된다. 이슈·PR에 응답이 없을 수 있다"**. 작성자는 후속 프로젝트 Mapigrade로 옮겨 감 | https://github.com/greensopinion/flutter-vector-map-tiles README | ☑️ |
| 라이선스 | BSD-3-Clause | GitHub API | ☑️ |
| 저사양 기기 성능 | 벡터를 기기에서 렌더링하므로 래스터보다 CPU·GPU·배터리 부담이 클 가능성. **이 기기군에서 측정한 자료는 없음** ❓ | — | ❓ |

→ 결론: OpenFreeMap + flutter_map은 **현재 베타 패키지에 의존**해야 하므로 1차 선택으로 권하지 않는다. 대안은 flutter_map이 아닌 **`maplibre_gl` 0.28.0(2026-11-03 게시, Flutter ≥3.44, Dart ≥3.12)**으로 OpenFreeMap 스타일을 네이티브 렌더링하는 것이다(OpenFreeMap 공식 문서도 모바일은 MapLibre Native를 권함). 다만 MapLibre Native는 네이티브 `.so`를 넣으므로 앱 크기, 16KB 정렬, 데이터 전송을 따로 검증해야 한다 ❓. (pub.dev API에서 버전만 확인 ☑️)

### 2.3 그 밖의 선택지

| 제공처 | 키 | 조건 | 출처 | 상태 |
|---|---|---|---|---|
| OSM France `tile.openstreetmap.fr/osmfr`, HOT `/hot` | 없음 | 기부로 운영. 서버별 사용 정책을 따르라는 안내뿐. 정책 원문은 확인 안 함 | https://wiki.openstreetmap.org/wiki/Raster_tile_providers (최종 수정 2026-10-02) | ⚠️ |
| OSM Germany `tile.openstreetmap.de` | 없음 | "상업·대량 트래픽 사용 제한" | 같은 위키 | ⚠️ |
| CARTO basemaps | **키 필요**(무료 키: 비상업 월 500만, 상업 월 100만 요청). 키가 없으면 워터마크 | https://github.com/CartoDB/basemap-styles README | ☑️ → "키 없음" 조건 불충족 |
| 자체 호스팅(Protomaps PMTiles 등을 R2·Pages에 올림) | 없음 | 서버 없이 정적 파일로 가능하다고 알려져 있음. 이 조사에서는 검증하지 않음 | — | ❓ |

---

## 3. 서울 중구·용산구·영등포구 OSM 한국어 라벨 품질

### 3.1 방법
- Overpass API(overpass-api.de)로 구 경계 relation(중구 2419947, 용산구 2419955, 영등포구 2414781)을 찾았다. 경계 relation 자체의 `name`, `name:ko`, `name:en`이 모두 정상이었다.
- 각 구 안에서 `name`이 있는 amenity/shop/tourism/office/healthcare(=POI), highway(도로·버스정류장 포함), 역(railway/public_transport=station)의 태그를 받아 집계했다(2026-11-03, 1회성 조회).
- 원본 응답은 scratchpad에만 두고 `data/raw/`에는 넣지 않았다(시설 데이터 소스가 아니고 ODbL 데이터라서).

### 3.2 결과

| 구 | 범주 | 이름 있는 객체 | `name`에 한글 포함 | `name:ko` 있음 | `name:ko`≠`name` | `name:en` 있음 | 한글 없는 `name` 예 |
|---|---|---|---|---|---|---|---|
| 중구 | POI | 8,475 | 7,963 (94%) | 1,012 (12%) | 137 | 985 (12%) | HiKR GROUND, Outback Steakhouse, Domino's |
| 중구 | 도로·정류장 | 2,032 | 2,028 (100%) | 1,694 (83%) | 6 | 1,813 (89%) | Airport Bus, Myeongdong Underground Shopping Center |
| 중구 | 역 | 24 | 24 (100%) | 20 (83%) | 0 | 22 (92%) | — |
| 용산구 | POI | 2,319 | 2,014 (87%) | 630 (27%) | 50 | 720 (31%) | SK, Honda KCC, Quiznos, CU |
| 용산구 | 도로·정류장 | 2,287 | 2,253 (99%) | 2,085 (91%) | 4 | 2,070 (91%) | UN Boulevard, Owen Avenue (옛 미군기지 안 도로) |
| 용산구 | 역 | 18 | 18 (100%) | 17 (94%) | 0 | 17 (94%) | — |
| 영등포구 | POI | 5,193 | 5,023 (97%) | 653 (13%) | 30 | 495 (10%) | GS25, OhyangJangyouk, G cafe |
| 영등포구 | 도로·정류장 | 2,745 | 2,743 (100%) | 2,381 (87%) | 6 | 2,386 (87%) | KBS |
| 영등포구 | 역 | 20 | 20 (100%) | 20 (100%) | 0 | 20 (100%) | — |

해석:
- **`name`의 기본값이 한국어다.** 한글이 없는 `name`은 대부분 영문 상호(GS25, CU, 프랜차이즈)이거나 용산 옛 미군기지 안의 영문 도로명이다. 렌더링에 `name`을 쓰면 한국어 지도가 된다.
- `name:ko`는 POI의 12~27%에만 있다. **`name:ko`를 우선 쓰고 없을 때 `name`으로 대체(fallback)**하면 문제가 없다. `name:ko`만 쓰면 대부분 비게 된다.
- 표본 확인: 서울역·영등포역은 `name`, `name:ko`, `name:en`, `name:ko-Latn`이 모두 있다. 국립중앙의료원(way 358284971)은 `name`=국립중앙의료원, `name:en`이 있고 `name:ko`는 없다.
- 이 수치는 OSM 객체 수를 센 것이지 **현실 대비 커버리지(누락률)가 아니다.** 실제 상점 수 대비 몇 %가 OSM에 있는지는 측정하지 않았다 ❓.

### 3.3 타일에서 실제로 보이는 라벨

| 타일 | 라벨 필드 | 한국어 표시 | 근거 | 상태 |
|---|---|---|---|---|
| OSM 표준(OSM Carto) | `name` | 한국어로 나옴(위 집계상 `name`=한국어) | OSM Carto는 `name`을 그림(일반적으로 알려진 사실이며 Carto 소스는 직접 확인 안 함). 위 집계 | ☑️ |
| OpenFreeMap Liberty 기본 스타일 | `name:nonlatin`이 있으면 **"`name:latin` 줄바꿈 `name:nonlatin`"**, 없으면 `name_en` → `name` | 기본값이면 **로마자와 한글이 2줄로** 나옴 → 저시력·한국어 사용자에게 불리 | 스타일 JSON의 `text-field`를 직접 확인 | ✅ |
| OpenMapTiles 스키마 | `ko`, `ko-Latn` 언어 필드 포함 | 스타일에서 `name:ko` → `name` 순서로 고치면 한국어만 표시 가능 | https://github.com/openmaptiles/openmaptiles/blob/master/openmaptiles.yaml `languages` | ☑️ |

### 3.4 시설 데이터로서의 OSM
- 키워드 표본 검색 결과: `요셉의원`(영등포구, node 8364806919, amenity=hospital, 영업시간·전화 없음)만 찾았다. 쪽방상담소, 노숙인 시설, 무료급식소는 찾지 못했다(`노숙`으로 검색하면 조형물 "노숙자예수"만 나옴).
- → 시설 정보는 **공공데이터 기반 자체 데이터**로 지도 위에 마커로 올린다(`docs/policy/data.md`대로). OSM 데이터를 가공해 앱 데이터에 섞으면 ODbL 동일조건(share-alike) 의무가 생기므로 섞지 않는 것을 기본값으로 한다(4절).

---

## 4. OSM ODbL 표기 요건 (앱 안)

출처: OSMF Attribution Guidelines https://osmfoundation.org/wiki/Licence/Attribution_Guidelines (2021-06-25 이사회 채택, 최종 편집 2026-09-10), https://www.openstreetmap.org/copyright — 두 출처 일치 ✅

| 항목 | 요건 |
|---|---|
| 문구 | "OpenStreetMap"을 openstreetmap.org/copyright에 링크(권장). "© OpenStreetMap contributors", "© OpenStreetMap"도 허용 |
| 라이선스 | 데이터가 ODbL로 제공된다는 점을 분명히 한다(copyright 페이지 링크로 충족) |
| 위치 | 보통 지도 **모서리**(어느 모서리든 가능). 지도 옆, 스플래시, 팝업도 가능 |
| 가시성 | **사용자가 지도를 조작하지 않아도 보여야 함** |
| 접기 | 닫기 동작 즉시, 지도 조작 시 자동, 또는 **5초 뒤 자동으로 접기 허용**. 접은 뒤에도 "(i)" 버튼이나 "정보" 메뉴에서 라이선스 정보를 찾을 수 있어야 함 |
| 스플래시 | 링크를 걸 수 없으면 "데이터 라이선스" 같은 메뉴에 링크를 둔다 |
| 가독성 | 쉽게 읽을 수 있어야 함(글꼴, 크기, 색, 대비, 위치, 표시 시간). **WCAG 준수 권장** |
| 동일조건 | OSM 데이터를 변경하거나 그 위에 데이터베이스를 만들어 배포하면 같은 라이선스(ODbL)로 배포해야 함 |

이 앱 적용:
- 지도 오른쪽 아래에 `RichAttributionWidget`: (i) 아이콘 + "© OpenStreetMap" 텍스트(접은 상태에서도 짧은 문구를 남기는 편이 안전). OpenFreeMap을 쓰면 "OpenFreeMap © OpenMapTiles"를 추가한다.
- 앱 안 **데이터 출처 화면**(`data.md` 1절)에 OSM, ODbL, 타일 제공처를 함께 적는다.
- 큰 글자 설정에서도 표기가 가려지거나 잘리지 않는지 확인한다(`ux-accessibility.md`).

---

## 5. 개인정보·데이터 보안 관점 (타일 요청)

| 항목 | 내용 | 상태 |
|---|---|---|
| 타일 요청이 드러내는 것 | 보고 있는 영역(z/x/y), IP, User-Agent(앱 패키지명) | 구조상 사실 ☑️ |
| OSMF 측 처리 | OSMF 개인정보 방침에서 타일 로그 보관 내용을 확인하지 않음 | ❓ |
| OpenFreeMap 측 처리 | 쿠키 없음(홈페이지). 로그 보관은 확인 안 함 | ❓ |
| 조치 | `privacy-location.md`의 "지도 SDK도 데이터를 보낸다" 항목에 타일 서버 도메인을 적고, 개인정보처리방침과 Play 데이터 보안 양식에 반영한다. 사용자 좌표 자체는 타일 요청에 넣지 않는다(타일 좌표는 보는 영역일 뿐이지만, 현재 위치로 지도를 이동하면 위치 근처 타일을 요청하게 된다는 점은 방침에 적는다) | 권고 |

---

## 6. 권장안 요약 (결정은 개발자가)

| 순위 | 구성 | 장점 | 단점 |
|---|---|---|---|
| 1 | **flutter_map 8.3.x + OSM 표준 래스터 + 내장 캐시** | 안정 패키지만 씀, 한국어 `name` 그대로 표시, 키 없음, 네이티브 `.so` 추가 없음 | SLA 없음, 차단 위험, 오프라인 다운로드 불가 |
| 예비 | 타일 URL 교체 구조 + OSM France 등(정책 확인 후) 또는 자체 호스팅 | 차단 대비 | 정책 확인·운영 부담 |
| 2 | flutter_map + vector_map_tiles 9 beta + OpenFreeMap(스타일의 라벨 필드 수정) | 무제한, 소량 오프라인 다운로드 허용 | 베타·최소 유지보수 패키지, 저사양 기기 성능 미검증 |
| 3 | maplibre_gl + OpenFreeMap | 공식 권장 경로, 벡터 성능 | 네이티브 SDK 추가(크기·16KB·전송 검증 필요), flutter_map이 아님 |

---

## 7. 길찾기 버튼: 지도 앱 딥링크 (키 불필요)

### 7.1 네이버 지도 `nmap://`

출처: NCP "지도 앱 연동 URL Scheme" https://guide.ncloud-docs.com/docs/application-maps-url-scheme-vpc (갱신 2026-09-17), 공공기관용 https://guide-gov.ncloud-docs.com/docs/naveropenapiv3-maps-url-scheme-url-scheme (갱신 2026-10-22) — 두 문서 일치 ✅. URL scheme 호출에는 API 키 파라미터가 없다(필수값은 `appname`뿐).

| 기능 | 형식 | 필수 |
|---|---|---|
| 장소 마커 | `nmap://place?lat=..&lng=..&name=<URL 인코딩>&appname=<applicationId>` | lat, lng, name, appname |
| **도보 길찾기** | `nmap://route/walk?dlat=..&dlng=..&dname=<URL 인코딩>&appname=..` | dlat, dlng, appname |
| 대중교통·자동차·자전거 | `nmap://route/public`, `/route/car`, `/route/bicycle` (파라미터 동일) | 〃 |
| 검색 | `nmap://search?query=..&appname=..` | query, appname |

- `appname`은 **모든 URL에 필수**(Android는 `applicationId`).
- 출발지(`slat`, `slng`, `sname`)를 생략하면 네이버 지도 앱이 **현재 위치**를 출발지로 쓴다 → `privacy-location.md`의 "목적지만 넘긴다" 규칙과 맞는다.
- 좌표 범위: 위도 31.43~44.35, 경도 122.37~132.00.
- 앱이 없을 때: 공식 예제는 `queryIntentActivities`로 확인한 뒤 `market://details?id=com.nhn.android.nmap`으로 보낸다. 패키지명은 Play 스토어 페이지에서 확인했다(https://play.google.com/store/apps/details?id=com.nhn.android.nmap, 제목 "네이버지도") ✅.
- 네이버 지도 **웹** 길찾기 URL 형식은 공식 문서에서 확인 못 함 ❓ → 웹 폴백은 카카오 링크를 쓴다.

### 7.2 카카오맵 `kakaomap://`

출처: 카카오맵 URL Scheme https://apis.map.kakao.com/ios_v2/docs/getting-started/urlscheme (Android 가이드 https://apis.map.kakao.com/android_v2/docs/api-guide 에서도 같은 페이지로 연결, 페이지 날짜 없음) ☑️

| 기능 | 형식 (원문 예시) |
|---|---|
| 좌표 보기 | `kakaomap://look?p=37.3952969470752,127.110449292622` |
| 길찾기 | `kakaomap://route?sp=37.39529,127.11044&ep=37.49795,127.02763&by=car` — `by`: `car`, `publictransit`, `foot`, `bicycle`(소문자). 경유지 `vp`~`vp5`(대중교통은 경유지 없음) |
| 장소 | `kakaomap://place?id=18577297` |
| 검색 | `kakaomap://search?q=맛집&p=37.3952,127.11044` |
| 앱이 없을 때(문서 안내) | 같은 기능의 모바일 웹 스킴 `http://m.map.kakao.com/scheme/...`, 또는 스토어 카카오맵 페이지 |

- **`sp`(출발지)를 생략할 수 있는지, 생략하면 현재 위치가 되는지는 문서에 없다** ❓ → 실기기에서 `kakaomap://route?ep=..&by=foot`를 테스트해야 한다. 출발지를 넣으려면 사용자 좌표를 넘겨야 하는데, 이는 기기 안 앱 사이의 인텐트라 서버 전송은 아니지만 정책상 피하는 것이 기본값이다.
- 패키지명 `net.daum.android.map`: Play 스토어 페이지로 확인(제목 "카카오맵 - 지도 / 내비게이션 / 길찾기 / 친구위치") ✅.

### 7.3 키 없는 웹 폴백 (두 앱이 모두 없을 때)

출처: Kakao 지도 Web API 가이드 "URL로 사용하기" https://apis.map.kakao.com/web/guide/#routeurl ☑️ — URL에 appkey 파라미터가 없다.

| 용도 | 형식 |
|---|---|
| 목적지까지 길찾기 | `https://map.kakao.com/link/to/<이름>,<위도>,<경도>` |
| 도보(출발지 포함) | `https://map.kakao.com/link/by/walk/<출발이름>,<위도>,<경도>/<도착이름>,<위도>,<경도>` |
| 지도 보기 | `https://map.kakao.com/link/map/<이름>,<위도>,<경도>` |

→ 권장 순서: 네이버 지도 앱 → 카카오맵 앱 → `map.kakao.com/link/to/...`(브라우저). 어느 경우든 주소 복사와 **전화 버튼**을 함께 보여 준다.

### 7.4 Android 11+(API 30) 패키지 가시성

출처: https://developer.android.com/training/package-visibility/declaring ✅(공식). targetSdk 30 이상에서는 다른 앱 조회(`queryIntentActivities`, `resolveActivity`) 결과가 필터링된다. 미리 확인하려면 매니페스트에 선언해야 한다.

```xml
<queries>
  <package android:name="com.nhn.android.nmap" />
  <package android:name="net.daum.android.map" />
</queries>
```

- 대안: 확인하지 않고 `startActivity`를 호출한 뒤 `ActivityNotFoundException`을 잡아 폴백하면 `<queries>`가 필요 없다(일반적인 Android 동작. 이 문서에서 별도 출처로 확인하지는 않음 ☑️).
- Flutter `url_launcher`의 `canLaunchUrl`도 Android 11+에서는 `<queries>`가 필요하다고 알려져 있다(이 조사에서는 확인 안 함 ❓).
- `QUERY_ALL_PACKAGES` 권한은 쓰지 않는다(Play 정책 심사 대상).

---

## 8. 네이버 장소 데이터 재사용 여부 (약관)

| 출처 | 내용 | 상태 |
|---|---|---|
| 네이버 이용약관(시행일 **2026-10-01**) https://policy.naver.com/rules/service.html | "네이버의 사전 허락 없이 자동화된 수단(예: 매크로 프로그램, 로봇(봇), 스파이더, 스크래퍼 등)을 이용하여 … 네이버 서비스에 게재된 회원의 아이디(ID), 게시물 등을 수집하거나 …" 금지. 서비스·소프트웨어 복사·수정 금지 | ✅ (원문 직접 확인) |
| NCP Maps 서비스 이용약관 v0.4 (2025-03-20 시행, NCP 약관 목록 https://www.ncloud.com/policy/terms/service 에서 현재본으로 연결) https://xv-ncloud.pstatic.net/images/provision/[민간]Maps서비스이용약관_v0.4_(CLEAN)_1742433558704.pdf | 7조⑨ 결과 데이터 무단 복제·저장·가공·배포·제3자 제공 금지. 7조⑪ "모든 Maps API의 결과 데이터는 값을 리턴 받는 즉시 1회 자신의 서비스에서 사용하는 것만 허용", 좌표를 모아 재사용하는 것은 "엄격히 금지" | ✅ (원문 PDF 직접 확인) |

→ 네이버 지도·검색의 장소 정보(이름·영업시간·전화·리뷰)는 **긁어 오거나 재사용할 수 없다.** 네이버 Geocoding으로 시설 좌표를 만들어 저장하는 것도 불가하다. `docs/policy/data.md` 1절 규칙과 일치한다. (딥링크로 네이버 지도 앱을 여는 것은 데이터 재사용이 아니므로 해당 없다.)

---

## 9. Google Play 요건 (2026-11 기준)

| 항목 | 현재 요건 | 출처 (확인 2026-11-03) | 상태 |
|---|---|---|---|
| **targetSdk** (신규 앱·업데이트) | **2026-08-31부터 Android 16(API 36) 이상**이어야 제출 가능. 연장 신청 시 2026-11-01까지였음(**이미 지남**). 기존 앱은 API 35 미만이면 새 Android 기기의 신규 사용자에게 노출 제한 | https://support.google.com/googleplay/android-developer/answer/11926878 , https://developer.android.com/google/play/requirements/target-sdk | ✅ |
| **16KB 페이지 크기** | Android 15(API 35)+를 타깃하는 모든 앱은 64비트 기기에서 16KB 지원 필요. **2027-02-01부터 16KB를 지원하지 않는 업데이트는 출시 불가** | https://developer.android.com/guide/practices/page-sizes , https://developer.android.com/16kb-page-size | ✅ |
| 16KB 과거 일정 | 원래 2025-11-01 시행, 연장 시 2026-05-31로 안내됐었음 | 2차 블로그, Broadcom KB https://knowledge.broadcom.com/external/article/411567/ | ⚠️ 과거 정보 |
| 16KB 빌드 | AGP ≥ 8.5.1, NDK r28+. 검증: APK Analyzer, `zipalign -c -P 16 -v 4 app.apk` | developer.android.com page-sizes | ✅ |
| 16KB와 이 구성 | flutter_map은 자체 `.so`가 없으므로 **`libflutter.so`(Flutter 엔진)와 다른 플러그인만 확인하면 된다.** Flutter 엔진의 16KB 지원 시작 버전은 공식 문서에서 찾지 못함(flutter/flutter#177147에 3.35.6 정렬 문제 보고) → 빌드한 APK로 직접 검증 | https://github.com/flutter/flutter/issues/177147 | ⚠️ |
| **개인 계정 비공개 테스트** | 2023-11-13 이후 만든 개인 계정은 프로덕션 신청 전 **최소 12명**이 **최근 14일 연속** 비공개 테스트에 참여(opt-in) | https://support.google.com/googleplay/android-developer/answer/14151465 + 2차 다수(예: https://ontest.app/blog/google-play-12-testers-14-days-requirement-explained) | ✅ |
| 참여도 심사 강화(2026) | 테스터의 실제 사용을 본다는 주장 | 2차 블로그만 | ⚠️ |

→ `docs/policy/play-store.md`의 targetSdk 36, 12명·14일은 현재와 일치한다. 16KB 마감일 2027-02-01은 아직 그 문서에 없으므로 추가를 권장한다.

---

## 10. 확인하지 못한 것

- OSM France, HOT 타일 서버의 사용 정책 원문.
- 내장 캐시가 `stale-if-error`를 처리하는지(오프라인에서 오래된 타일을 쓸 수 있는지), 캐시 한도 설정 API의 정확한 이름.
- `flutter_map_cache` 라이선스, `path_provider_android` minSdk.
- vector_map_tiles·maplibre_gl의 저사양 기기 성능, maplibre_gl 네이티브 라이브러리의 크기와 16KB 정렬.
- `kakaomap://route`에서 `sp`를 생략할 수 있는지.
- 네이버 지도 웹 길찾기 URL 형식.
- OSMF·OpenFreeMap의 타일 접속 로그 보관 정책.
- Flutter 엔진 16KB 지원 시작 버전(공식 문서).
- OSM 커버리지의 현실 대비 누락률(객체 수만 셌음).
