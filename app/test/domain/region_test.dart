import 'package:flutter_test/flutter_test.dart';
import 'package:majung/domain/geo.dart';
import 'package:majung/domain/region.dart';

import '../fixtures.dart';

void main() {
  final catalog = RegionCatalog.fromJson(regionsJson());

  test('코드 순서로 시도 목록을 만든다', () {
    expect(catalog.sidos, ['서울', '부산', '경기']);
    expect(catalog.inSido('서울').map((r) => r.sigungu), ['중구', '용산구', '영등포구']);
  });

  test('코드로 찾기, 없으면 null', () {
    expect(catalog.byCode('11170')?.label, '서울 용산구');
    expect(catalog.byCode('00000'), isNull);
  });

  test('가장 가까운 시군구', () {
    expect(catalog.nearest(const GeoPoint(37.5547, 126.9707))?.label, '서울 중구');
    expect(catalog.nearest(const GeoPoint(35.1151, 129.0422))?.sido, '부산');
    expect(RegionCatalog.empty.nearest(const GeoPoint(37.5, 127.0)), isNull);
  });

  test('잘못된 항목·중복은 건너뛴다', () {
    final c = RegionCatalog.fromJson([
      {'code': '11140', 'sido': '서울', 'sigungu': '중구', 'lat': 37.56, 'lng': 126.98},
      {'code': '11140', 'sido': '서울', 'sigungu': '중구(중복)', 'lat': 37.56, 'lng': 126.98},
      {'code': '1', 'sido': '', 'sigungu': 'x', 'lat': 37.0, 'lng': 127.0},
      {'code': '2', 'sido': '서울', 'sigungu': '좌표없음'},
      {'code': '3', 'sido': '서울', 'sigungu': '국외', 'lat': 0, 'lng': 0},
      'garbage',
    ]);
    expect(c.regions.map((r) => r.sigungu), ['중구']);
  });

  test('목록이 아니면 FormatException', () {
    expect(() => RegionCatalog.fromJson({'a': 1}), throwsFormatException);
  });
}
