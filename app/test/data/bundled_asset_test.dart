import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:majung/domain/category.dart';
import 'package:majung/domain/dataset.dart';

/// 앱에 실제로 들어가는 데이터 파일이 앱 규칙으로 문제없이 읽히는지.
void main() {
  final raw = File('assets/data/facilities.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final dataset = Dataset.fromJson(json);

  test('모든 시설이 앱 검증을 통과한다 (건너뛴 항목 0)', () {
    expect(dataset.skipped, 0);
    expect(dataset.facilities.length, (json['facilities'] as List).length);
  });

  test('1차 범위 카테고리만 있고 둘 다 비어 있지 않다', () {
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
}
