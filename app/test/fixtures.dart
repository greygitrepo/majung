/// 테스트 전용 가짜 데이터. 실제 시설 정보가 아니다.
Map<String, dynamic> facilityJson({
  String id = 'test-1',
  String name = '테스트 급식소',
  String category = 'meal',
  double lat = 37.5550,
  double lng = 126.9710,
  String? phone = '02-000-0000',
  List<Map<String, dynamic>>? hours,
  String lastVerified = '2026-10-01',
  String? eligibility = '누구나',
  String? requirements,
  String? hoursNote,
  String? holidayPolicy,
}) =>
    {
      'id': id,
      'name': name,
      'category': category,
      'address': '서울 중구 테스트로 1',
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
      'verified_by': 'public_data',
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
