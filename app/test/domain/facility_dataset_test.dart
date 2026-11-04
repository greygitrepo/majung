import 'package:flutter_test/flutter_test.dart';
import 'package:majung/domain/category.dart';
import 'package:majung/domain/dataset.dart';
import 'package:majung/domain/facility.dart';
import 'package:majung/domain/freshness.dart';
import 'package:majung/domain/geo.dart';
import 'package:majung/domain/opening_hours.dart';
import 'package:majung/domain/ranking.dart';

import '../fixtures.dart';

void main() {
  group('Facility.fromJson', () {
    test('정상 데이터', () {
      final f = Facility.fromJson(facilityJson());
      expect(f.name, '테스트 급식소');
      expect(f.category, FacilityCategory.meal);
      expect(f.hours.rules, hasLength(1));
      expect(f.lastVerified, DateTime(2026, 10, 1));
      expect(f.isFree, isTrue);
    });

    test('필수 필드가 없으면 거부', () {
      for (final key in ['id', 'name', 'address', 'source_id', 'last_verified']) {
        final json = facilityJson()..remove(key);
        expect(() => Facility.fromJson(json), throwsFormatException, reason: key);
      }
    });

    test('빈 문자열 이름은 거부', () {
      expect(() => Facility.fromJson(facilityJson(name: '  ')), throwsFormatException);
    });

    test('국내 범위 밖 좌표 거부 (위경도 뒤바뀜 포함)', () {
      expect(() => Facility.fromJson(facilityJson(lat: 126.97, lng: 37.55)), throwsFormatException);
    });

    test('알 수 없는 분류 거부', () {
      expect(() => Facility.fromJson(facilityJson(category: 'casino')), throwsFormatException);
    });

    test('전화번호 형식 오류 거부', () {
      expect(() => Facility.fromJson(facilityJson(phone: '전화없음')), throwsFormatException);
    });

    test('전화번호 없음은 허용', () {
      expect(Facility.fromJson(facilityJson(phone: null)).phone, isNull);
    });

    test('운영시간 없음은 허용 (모름 처리)', () {
      final json = facilityJson()..remove('hours');
      expect(Facility.fromJson(json).hours.isEmpty, isTrue);
    });
  });

  group('isValidKoreanPhone', () {
    test('허용', () {
      for (final p in ['02-123-4567', '02-1234-5678', '031-123-4567', '010-1234-5678', '1600-9582', '120', '(02) 123 4567']) {
        expect(isValidKoreanPhone(p), isTrue, reason: p);
      }
    });
    test('거부', () {
      for (final p in ['', 'abc', '12-34', '+1 555 1234', '02-12']) {
        expect(isValidKoreanPhone(p), isFalse, reason: p);
      }
    });
    test('dialDigits', () {
      expect(dialDigits('1600-9582'), '16009582');
    });
  });

  group('Dataset.fromJson', () {
    test('잘못된 항목은 건너뛰고 개수를 센다', () {
      final ds = Dataset.fromJson(datasetJson(facilities: [
        facilityJson(id: 'a'),
        facilityJson(id: 'b', lat: 0, lng: 0),
        {'garbage': true},
      ]));
      expect(ds.facilities.map((f) => f.id), ['a']);
      expect(ds.skipped, 2);
    });

    test('중복 id 는 첫 번째만', () {
      final ds = Dataset.fromJson(datasetJson(facilities: [
        facilityJson(id: 'a', name: '첫번째'),
        facilityJson(id: 'a', name: '두번째'),
      ]));
      expect(ds.facilities.single.name, '첫번째');
      expect(ds.skipped, 1);
    });

    test('버전이 없으면 묶음 전체 거부', () {
      final json = datasetJson()..remove('version');
      expect(() => Dataset.fromJson(json), throwsFormatException);
    });

    test('facilities 가 없으면 거부', () {
      final json = datasetJson()..remove('facilities');
      expect(() => Dataset.fromJson(json), throwsFormatException);
    });

    test('공휴일 판정', () {
      final ds = Dataset.fromJson(datasetJson(holidays: ['2026-12-25']));
      expect(ds.isHoliday(DateTime(2026, 12, 25, 15)), isTrue);
      expect(ds.isHoliday(DateTime(2026, 12, 24)), isFalse);
    });

    test('출처 조회', () {
      expect(Dataset.fromJson(datasetJson()).sourceById('test-source')?.license, '공공누리 1유형');
    });
  });

  group('Facility 확인 상태', () {
    final now = DateTime(2026, 11, 2, 12); // 월 12:00, 점심 시간
    test('사람이 확인한 시설만 지금 열림을 계산한다', () {
      final official = Facility.fromJson(facilityJson());
      final public = Facility.fromJson(facilityJson(verifiedBy: 'public_data'));
      expect(official.hoursTrusted, isTrue);
      expect(official.statusAt(now).isOpenNow, isTrue);
      expect(public.hoursTrusted, isFalse, reason: '공공데이터 시간은 자주 틀린다 (decisions #16)');
      expect(public.statusAt(now).state, OpenState.unknown);
    });
    test('새 필드: 시도, 대상, 진료 종류', () {
      final f = Facility.fromJson(facilityJson(sido: '전남광주', audience: 'senior', subtype: 'health_center'));
      expect(f.sido, '전남광주');
      expect(f.audience, Audience.senior);
      expect(f.clinicType, ClinicType.healthCenter);
      final plain = Facility.fromJson(facilityJson(subtype: 'unknown-kind'));
      expect(plain.audience, Audience.general);
      expect(plain.clinicType, isNull);
    });
    test('verified_by: official', () {
      expect(Facility.fromJson(facilityJson()).verifiedBy, VerifiedBy.official);
    });
  });

  group('rankFacilities', () {
    final now = DateTime(2026, 11, 2, 12); // 월 12:00
    const seoulStation = GeoPoint(37.5547, 126.9707);
    final always = [
      {'days': ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'], 'open': '00:00', 'close': '24:00'},
    ];
    final never = [
      {'days': ['sun'], 'open': '09:00', 'close': '10:00'},
    ];
    final ds = Dataset.fromJson(datasetJson(facilities: [
      facilityJson(id: 'closed-near', name: '닫힌가까운', hours: never, lat: 37.5548, lng: 126.9708),
      facilityJson(id: 'open-far', name: '열린먼', hours: always, lat: 37.5156, lng: 126.9073),
      facilityJson(id: 'open-near', name: '열린가까운', hours: always, lat: 37.5550, lng: 126.9710),
      facilityJson(id: 'unknown', name: '모름', hours: [], lat: 37.5560, lng: 126.9720),
      facilityJson(id: 'public-open', name: '공공데이터', hours: always, verifiedBy: 'public_data', lat: 37.5549, lng: 126.9709),
      facilityJson(id: 'expired-open', name: '오래된', hours: always, lastVerified: '2025-01-01'),
      facilityJson(id: 'senior', name: '경로식당', hours: always, audience: 'senior'),
      facilityJson(id: 'busan', name: '부산급식', hours: always, lat: 35.1151, lng: 129.0422, sido: '부산'),
      facilityJson(id: 'shelter', name: '쉼터', category: 'shelter', hours: always),
    ]));

    List<String> ids(GeoPoint origin, {CategoryGroup group = CategoryGroup.meal}) =>
        rankFacilities(ds, group: group, now: now, origin: origin).map((r) => r.facility.id).toList();

    test('확인된 열린 곳 → 나머지 가까운 순 → 오래된 정보 → 어르신 경로식당', () {
      expect(ids(seoulStation), ['open-near', 'open-far', 'closed-near', 'public-open', 'unknown', 'expired-open', 'senior']);
      final ranked = rankFacilities(ds, group: CategoryGroup.meal, now: now, origin: seoulStation);
      expect(ranked.first.distance, lessThan(100));
      expect(ranked.firstWhere((r) => r.facility.id == 'expired-open').freshness, Freshness.expired);
    });

    test('먼 지역(부산)은 가까운 곳이 충분하면 빠진다', () {
      expect(ids(seoulStation), isNot(contains('busan')));
    });

    test('부산에서는 부산이 먼저, 가까운 곳이 모자라면 먼 곳으로 채운다', () {
      final busan = ids(const GeoPoint(35.1000, 129.0300));
      expect(busan.first, 'busan');
      expect(busan.where((id) => id != 'senior').length, minNearbyCount);
    });

    test('카테고리 묶음으로 거른다', () {
      expect(ids(seoulStation, group: CategoryGroup.sleep), ['shelter']);
    });

    test('기준 위치가 없으면 빈 목록 (전국을 늘어놓지 않는다)', () {
      expect(rankFacilities(ds, group: CategoryGroup.meal, now: now), isEmpty);
    });

    test('진료: 무료 진료소 → 입원 지원 → 보건소', () {
      final clinics = Dataset.fromJson(datasetJson(facilities: [
        facilityJson(id: 'hc', category: 'clinic', subtype: 'health_center', hours: [], lat: 37.5548, lng: 126.9708),
        facilityJson(id: 'support', category: 'clinic', subtype: 'hospital_support', hours: [], lat: 37.56, lng: 126.98),
        facilityJson(id: 'free', category: 'clinic', subtype: 'free_clinic', hours: [], lat: 37.50, lng: 126.90),
      ]));
      final ranked = rankFacilities(clinics, group: CategoryGroup.clinic, now: now, origin: seoulStation);
      expect(ranked.map((r) => r.facility.id), ['free', 'support', 'hc']);
    });
  });
}
