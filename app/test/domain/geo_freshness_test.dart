import 'package:flutter_test/flutter_test.dart';
import 'package:majung/domain/freshness.dart';
import 'package:majung/domain/geo.dart';

// 테스트용 좌표 (대략값).
const seoulStation = GeoPoint(37.5547, 126.9707);
const yeongdeungpo = GeoPoint(37.5156, 126.9073);
const busanStation = GeoPoint(35.1151, 129.0422);

void main() {
  group('distanceMeters', () {
    test('같은 지점은 0', () {
      expect(distanceMeters(seoulStation, seoulStation), 0);
    });
    test('서울역~영등포역은 약 7km', () {
      final d = distanceMeters(seoulStation, yeongdeungpo);
      expect(d, inInclusiveRange(6500, 7500));
    });
    test('대칭', () {
      final a = distanceMeters(seoulStation, busanStation);
      final b = distanceMeters(busanStation, seoulStation);
      expect(a, closeTo(b, 0.001));
    });
    test('서울역~부산역은 약 325km', () {
      expect(distanceMeters(seoulStation, busanStation), inInclusiveRange(310000, 340000));
    });
  });

  group('formatDistance', () {
    test('1km 미만은 10m 단위', () {
      expect(formatDistance(3), '10m');
      expect(formatDistance(354), '350m');
      expect(formatDistance(996), '1000m');
    });
    test('1km 이상은 소수 한 자리', () {
      expect(formatDistance(1000), '1.0km');
      expect(formatDistance(1260), '1.3km');
    });
    test('10km 이상은 정수', () {
      expect(formatDistance(12400), '12km');
    });
  });

  test('walkingMinutes: 최소 1분, 1km는 약 20분', () {
    expect(walkingMinutes(0), 1);
    expect(walkingMinutes(1000), 20);
  });

  test('isInKorea', () {
    expect(seoulStation.isInKorea, isTrue);
    expect(const GeoPoint(33.25, 126.56).isInKorea, isTrue, reason: '서귀포');
    expect(const GeoPoint(0, 0).isInKorea, isFalse);
    expect(const GeoPoint(126.97, 37.55).isInKorea, isFalse, reason: '위도·경도 뒤바뀜');
  });

  group('freshness', () {
    final verified = DateTime(2026, 1, 1);
    test('90일까지 fresh', () {
      expect(freshnessOf(verified, DateTime(2026, 4, 1, 23, 59)), Freshness.fresh); // 90일
    });
    test('91일부터 stale', () {
      expect(freshnessOf(verified, DateTime(2026, 4, 2)), Freshness.stale);
    });
    test('180일까지 stale, 181일부터 expired', () {
      expect(freshnessOf(verified, DateTime(2026, 6, 30)), Freshness.stale); // 180일
      expect(freshnessOf(verified, DateTime(2026, 7, 1)), Freshness.expired);
    });
    test('미래 날짜(시계 오류)는 fresh', () {
      expect(freshnessOf(verified, DateTime(2025, 12, 1)), Freshness.fresh);
    });
    test('daysBetween 은 시각과 무관', () {
      expect(daysBetween(DateTime(2026, 3, 1, 23, 59), DateTime(2026, 3, 2, 0, 1)), 1);
    });
  });
}
