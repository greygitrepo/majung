# 시설 데이터 정책

> 이 앱의 진짜 난이도는 앱이 아니라 데이터다. 틀린 정보는 정보가 없는 것보다 나쁘다 — 배고픈 사람이 문 닫은 급식소까지 걸어가게 만든다.

## 1. 데이터 출처

우선순위 순:

1. **공공데이터**: 공공데이터포털(data.go.kr), 서울열린데이터광장, 지자체 공개 목록
2. **기관 공식 안내**: 서울시 복지 누리집, 각 기관·푸드뱅크 공식 페이지
3. **현장 확인**: 기관 전화 확인, 실무자·자원봉사자 제보 (검증 후 반영)

규칙:

- **라이선스를 확인하고 기록한다.** 공공누리 유형(1~4유형)에 따라 출처 표시, 상업적 이용, 변경 가능 여부가 다르다. 각 데이터셋의 유형을 `data/sources.yaml`에 적는다.
- 앱 안에 **데이터 출처 화면**을 둔다(기관명, 데이터셋명, 라이선스).
- 네이버·카카오 지도의 장소 정보, 블로그 등 **이용약관상 재사용이 허락되지 않은 데이터를 긁어오지 않는다.**
- 원본 데이터는 `data/raw/`에 받은 날짜와 함께 보관하고 가공 스크립트로만 변환한다. 수작업 수정은 `data/overrides/`에 근거와 함께 따로 둔다.

## 2. 데이터 스키마 (최소 필드)

```yaml
id: string            # 안정적인 고유 ID (출처 ID 기반)
name: string
category: meal | shelter | foodbank | foodmarket | shower | laundry | clinic | counseling
address: string
lat: number
lng: number
phone: string?
hours:                # 요일별 운영 시간, 구조화된 형태
  - days: [mon, tue, ...]
    open: "11:30"
    close: "13:00"
hours_note: string?   # 구조화가 안 되는 원문 ("셋째 주 휴무" 등)
eligibility: string?  # 이용 대상 ("65세 이상", "노숙인", "누구나")
requirements: string? # 이용 조건 ("신분증 필요", "사전 등록")
cost: free | low_cost
source_id: string     # data/sources.yaml 참조
source_url: string?
last_verified: date   # 마지막으로 사람이 또는 원본에서 확인한 날짜
verified_by: public_data | official | phone | field | report
                      # official = 기관 공식 안내(홈페이지·공고)를 사람이 확인함
sido: string          # 시도 (2026-07-01 이후 이름. 예: "서울", "전남광주", "경기")
sigungu: string?      # 시군구 (예: "용산구", "화성시 동탄구")
audience: general | senior   # senior = 어르신 경로식당 등 미리 등록해야 하는 곳 (기본 general)
subtype: string?      # clinic 전용: free_clinic | health_center | hospital_support
```

- **운영시간 규칙 (decisions #16)**: `verified_by: public_data` 인 시설은 `hours` 를 비우고 원문을 `hours_note` 에 "공공데이터 안내: …" 로 넣는다. 앱은 "지금 열림"을 계산하지 않고 "가기 전에 전화로 확인하세요"를 보여준다. 사람이 확인한(`official`/`phone`/`field`) 시설만 구조화된 `hours` 를 갖는다.
- 전화번호 형식이 이상하면(지역번호 없음, 팩스 의심) `phone` 을 비우고 빌드 보고서 "전화 확인 필요"에 남긴다.
- 지역 목록은 `app/assets/data/regions.json` (`[{code, sido, sigungu, lat, lng}]`, 시군구 대표 좌표). 위치 권한 없이 지역을 고르는 데 쓴다.

- 운영 요일, 이용 대상, 이용 조건은 이 앱이 일반 지도 앱과 다른 핵심 가치다. 비어 있으면 "확인 필요"로 표시하고 지어내지 않는다.
- 좌표가 없는 데이터는 지오코딩하되, 지오코딩한 좌표임을 표시(`geocoded: true`)하고 대표 장소는 수동 검증한다.

## 3. 신선도

- 모든 시설에 **"마지막 확인: YYYY-MM-DD"** 를 화면에 표시한다.
- `last_verified`가 **90일**을 넘으면 "정보가 오래됐을 수 있어요. 방문 전 전화로 확인하세요" 경고를 표시한다.
- **180일**을 넘으면 기본 목록에서 숨기거나 맨 아래로 내린다(설정으로 결정).
- "지금 열림" 판정은 구조화된 `hours`가 있을 때만 하고, 공휴일·명절은 별도 휴무 정보가 없으면 "공휴일 운영 확인 필요"로 표시한다.
- 시설마다 **"정보가 틀렸어요" 신고** 경로를 둔다. 신고는 개인정보 없이(시설 ID + 항목 + 자유 메모) 받는다.

## 4. 데이터 처리 코드 규칙

- 수집·가공 파이프라인은 앱과 분리한다(`pipeline/`). 같은 입력이면 같은 출력이 나오게(결정적) 만든다.
- 가공 결과는 검증 단계를 통과해야 배포한다: 필수 필드, 좌표가 대한민국 범위 안인지, 전화번호 형식, 중복 시설(이름+주소 유사도) 검사.
- 앱에 배포하는 파일에는 버전(생성 일시)을 넣고, 앱은 더 새 버전일 때만 교체한다. 받다가 실패하면 기존 데이터를 유지한다.
- 범위는 **전국 16개 시도** (decisions #14). 공공데이터는 출처끼리 다른 경우가 많으므로(2026-11-04 표본 41% 불일치) 운영 종료·1년 넘은 정보는 빼고, 사람이 확인한 보정은 `data/overrides/`에 근거(URL·확인일)와 함께 둔다.
