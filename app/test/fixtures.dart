/// 테스트 전용 가짜 데이터. 실제 시설 정보가 아니다.
Map<String, dynamic> facilityJson({
  String id = 'test-1',
  String name = '테스트 급식소',
  String category = 'meal',
  String address = '서울 중구 테스트로 1',
  double lat = 37.5550,
  double lng = 126.9710,
  String? phone = '02-000-0000',
  List<Map<String, dynamic>>? hours,
  String lastVerified = '2026-10-01',
  String? eligibility = '누구나',
  String? requirements,
  String? hoursNote,
  String? holidayPolicy,
  // 기본은 사람이 확인한 시설(운영시간을 믿음). 공공데이터 원문 시설은 'public_data'.
  String verifiedBy = 'official',
  String sido = '서울',
  String? audience,
  String? subtype,
  bool geocoded = false,
}) =>
    {
      'id': id,
      'name': name,
      'category': category,
      'address': address,
      'lat': lat,
      'lng': lng,
      'phone': phone,
      'hours': hours ??
          [
            {'days': ['mon', 'tue', 'wed', 'thu', 'fri'], 'open': '11:30', 'close': '13:00'},
          ],
      'hours_note': hoursNote,
      'holiday_policy': holidayPolicy,
      'eligibility': eligibility,
      'requirements': requirements,
      'cost': 'free',
      'source_id': 'test-source',
      'last_verified': lastVerified,
      'verified_by': verifiedBy,
      'sido': sido,
      'audience': ?audience,
      'subtype': ?subtype,
      if (geocoded) 'geocoded': true,
    };

Map<String, dynamic> datasetJson({
  String version = '2026-11-01T00:00:00+09:00',
  List<Map<String, dynamic>>? facilities,
  List<String> holidays = const [],
}) =>
    {
      'version': version,
      'holidays': holidays,
      'sources': [
        {'id': 'test-source', 'name': '테스트 데이터', 'provider': '테스트', 'license': '공공누리 1유형'},
      ],
      'facilities': facilities ?? [facilityJson()],
    };

/// 테스트용 시군구 몇 곳 (좌표는 대략값).
const seoulJunggu = '11140';
List<Map<String, dynamic>> regionsJson() => [
      {'code': '11140', 'sido': '서울', 'sigungu': '중구', 'lat': 37.5600, 'lng': 126.9800},
      {'code': '11170', 'sido': '서울', 'sigungu': '용산구', 'lat': 37.5320, 'lng': 126.9900},
      {'code': '11560', 'sido': '서울', 'sigungu': '영등포구', 'lat': 37.5260, 'lng': 126.8960},
      {'code': '26110', 'sido': '부산', 'sigungu': '중구', 'lat': 35.1060, 'lng': 129.0320},
      {'code': '41111', 'sido': '경기', 'sigungu': '수원시 장안구', 'lat': 37.3040, 'lng': 127.0100},
    ];
