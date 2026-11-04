import 'package:flutter_test/flutter_test.dart';
import 'package:majung/domain/category.dart';
import 'package:majung/domain/dataset.dart';
import 'package:majung/domain/facility.dart';
import 'package:majung/domain/freshness.dart';
import 'package:majung/domain/geo.dart';
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

  group('rankFacilities', () {
    final now = DateTime(2026, 11, 2, 12); // 월 12:00
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
      facilityJson(id: 'unknown', name: '모름', hours: []),
      facilityJson(id: 'expired-open', name: '오래된', hours: always, lastVerified: '2025-01-01'),
      facilityJson(id: 'shelter', name: '쉼터', category: 'shelter', hours: always),
    ]));

    test('열린 곳 → 닫힌 곳 → 모름 → 오래된 정보, 같은 묶음은 가까운 순', () {
      final ranked = rankFacilities(ds, group: CategoryGroup.meal, now: now, origin: Landmark.seoulStation.point);
      expect(ranked.map((r) => r.facility.id), ['open-near', 'open-far', 'closed-near', 'unknown', 'expired-open']);
      expect(ranked.last.freshness, Freshness.expired);
      expect(ranked.first.distance, lessThan(100));
    });

    test('카테고리 묶음으로 거른다', () {
      final ranked = rankFacilities(ds, group: CategoryGroup.sleep, now: now);
      expect(ranked.map((r) => r.facility.id), ['shelter']);
    });

    test('기준 위치가 없으면 거리 없이 이름순', () {
      final ranked = rankFacilities(ds, group: CategoryGroup.meal, now: now);
      expect(ranked.first.distance, isNull);
      expect(ranked.take(2).map((r) => r.facility.name), ['열린가까운', '열린먼']);
    });
  });
}
