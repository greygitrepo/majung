import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:majung/domain/category.dart';
import 'package:majung/domain/dataset.dart';
import 'package:majung/domain/facility.dart';
import 'package:majung/domain/region.dart';

/// 앱에 실제로 들어가는 데이터 파일이 앱 규칙으로 문제없이 읽히는지.
void main() {
  final raw = File('assets/data/facilities.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final dataset = Dataset.fromJson(json);

  test('모든 시설이 앱 검증을 통과한다 (건너뛴 항목 0)', () {
    expect(dataset.skipped, 0);
    expect(dataset.facilities.length, (json['facilities'] as List).length);
  });

  test('1차 범위 카테고리만 있고 모두 비어 있지 않다', () {
    for (final f in dataset.facilities) {
      expect(CategoryGroup.enabled.any((g) => g.contains(f.category)), isTrue, reason: f.name);
    }
    for (final g in CategoryGroup.enabled) {
      expect(dataset.facilities.where((f) => g.contains(f.category)), isNotEmpty, reason: g.name);
    }
  });

  test('모든 시설의 출처가 출처 목록에 있다', () {
    for (final f in dataset.facilities) {
      expect(dataset.sourceById(f.sourceId), isNotNull, reason: f.name);
    }
  });

  test('공휴일 목록이 있다', () {
    expect(dataset.holidays, isNotEmpty);
  });

  test('공공데이터 시설은 구조화된 운영시간이 없다 (decisions #16)', () {
    for (final f in dataset.facilities.where((f) => f.verifiedBy == VerifiedBy.publicData)) {
      expect(f.hours.rules, isEmpty, reason: f.name);
    }
  });

  test('전국 데이터: 서울 밖 시설과 시도 정보가 있다', () {
    final sidos = {for (final f in dataset.facilities) f.sido};
    expect(sidos, isNot(contains(null)));
    expect(sidos.length, greaterThan(10));
  });

  group('regions.json', () {
    final regions = RegionCatalog.fromJson(jsonDecode(File('assets/data/regions.json').readAsStringSync()));
    test('16개 시도, 행정구역 개편 반영', () {
      expect(regions.sidos.length, 16);
      expect(regions.sidos, contains('전남광주'));
      expect(regions.sidos, isNot(contains('광주')));
      final incheon = regions.inSido('인천').map((r) => r.sigungu).toSet();
      // 2026-07-01 개편 (data/research/regions-incheon-seohae.md)
      expect(incheon, containsAll(['제물포구', '영종구', '검단구', '서해구']));
      expect(incheon, isNot(contains('중구')));
      expect(incheon, isNot(contains('동구')));
      expect(regions.inSido('경기').map((r) => r.sigungu), contains('화성시 동탄구'));
    });
    test('시설의 시도가 모두 지역 목록에 있다', () {
      for (final f in dataset.facilities) {
        expect(regions.sidos, contains(f.sido), reason: f.name);
      }
    });
    test('통합 테스트가 쓰는 코드가 있다', () {
      expect(regions.byCode('11170')?.label, '서울 용산구');
      expect(regions.byCode('26110')?.label, '부산 중구');
    });
  });
}
