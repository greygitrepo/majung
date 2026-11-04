import 'package:flutter_test/flutter_test.dart';
import 'package:majung/domain/category.dart';
import 'package:majung/domain/dataset.dart';
import 'package:majung/domain/facility.dart';
import 'package:majung/domain/geo.dart';
import 'package:majung/domain/saved_places.dart';

import '../fixtures.dart';

/// 월요일 12:00 (기본 급식 시간 11:30~13:00 안).
final now = DateTime(2026, 11, 2, 12);

Dataset dataset(List<Map<String, dynamic>> facilities) => Dataset.fromJson(datasetJson(facilities: facilities));

SavedPlace place(
  String id, {
  String name = '테스트 급식소',
  String address = '서울 중구 테스트로 1',
  String? phone = '02-000-0000',
  FacilityCategory category = FacilityCategory.meal,
  String? sido = '서울',
}) =>
    SavedPlace(
      id: id,
      name: name,
      category: category,
      address: address,
      phone: phone,
      sido: sido,
      savedAt: DateTime(2026, 11, 1),
    );

void main() {
  group('저장값 읽고 쓰기', () {
    test('저장한 그대로 다시 읽는다', () {
      final f = Facility.fromJson(facilityJson(id: 'meal-1', phone: '02-111-1111'));
      final p = SavedPlace.fromFacility(f, DateTime(2026, 11, 4, 23, 50));
      final back = decodeSavedPlaces(encodeSavedPlaces([p]));
      expect(back, hasLength(1));
      expect(back.single.id, 'meal-1');
      expect(back.single.name, '테스트 급식소');
      expect(back.single.category, FacilityCategory.meal);
      expect(back.single.phone, '02-111-1111');
      expect(back.single.sido, '서울');
      expect(back.single.savedAt, DateTime(2026, 11, 4), reason: '날짜만 남긴다');
    });

    test('전화번호가 없는 시설도 저장된다', () {
      final f = Facility.fromJson(facilityJson(id: 'meal-1', phone: null));
      final back = decodeSavedPlaces(encodeSavedPlaces([SavedPlace.fromFacility(f, now)]));
      expect(back.single.phone, isNull);
    });

    test('비었거나 깨진 저장값은 빈 목록 (앱이 멈추지 않음)', () {
      expect(decodeSavedPlaces(null), isEmpty);
      expect(decodeSavedPlaces(''), isEmpty);
      expect(decodeSavedPlaces('{깨짐'), isEmpty);
      expect(decodeSavedPlaces('{"id": "x"}'), isEmpty, reason: '목록이 아님');
      expect(decodeSavedPlaces('"문자열"'), isEmpty);
    });

    test('깨진 항목과 중복은 건너뛰고 나머지는 살린다', () {
      final good = encodeSavedPlaces([place('a'), place('b')]);
      final raw = good.replaceFirst('[', '[1, {"id": "c"}, {"id":"d","name":"n","category":"모름","address":"x","saved_at":"2026-11-01"},');
      final withDup = raw.replaceFirst(']', ',${encodeSavedPlaces([place('a')]).substring(1)}');
      final back = decodeSavedPlaces(withDup);
      expect(back.map((p) => p.id), ['a', 'b']);
    });
  });

  group('데이터가 바뀌었을 때 맞추기', () {
    test('ID가 그대로면 이름·전화를 최신으로, 저장한 날은 유지', () {
      final d = dataset([facilityJson(id: 'meal-1', name: '새 이름', phone: '02-222-2222')]);
      final out = reconcileSavedPlaces([place('meal-1', name: '옛 이름', phone: '02-111-1111')], d);
      expect(out.single.name, '새 이름');
      expect(out.single.phone, '02-222-2222');
      expect(out.single.savedAt, DateTime(2026, 11, 1));
    });

    test('ID만 바뀐 시설은 같은 분류·이름·주소로 다시 찾는다', () {
      final d = dataset([facilityJson(id: 'meal-new', name: '사랑 급식소', address: '서울 중구 세종대로 10 (태평로1가)')]);
      final out = reconcileSavedPlaces([place('meal-old', name: '사랑급식소', address: '서울 중구 세종대로 10')], d);
      expect(out.single.id, 'meal-new', reason: '띄어쓰기·괄호 차이는 같은 곳으로 본다');
    });

    test('분류가 다르면 이름·주소가 같아도 옮기지 않는다', () {
      final d = dataset([facilityJson(id: 'shelter-new', category: 'shelter')]);
      final out = reconcileSavedPlaces([place('meal-old')], d);
      expect(out.single.id, 'meal-old');
    });

    test('못 찾으면 그대로 둔다 (지우지 않음)', () {
      final d = dataset([facilityJson(id: 'other', name: '다른 곳', address: '부산 중구 1')]);
      final saved = [place('gone', name: '없어진 곳', address: '서울 중구 2')];
      expect(reconcileSavedPlaces(saved, d).single.id, 'gone');
    });

    test('두 저장 항목이 같은 시설로 모이면 하나만 남긴다', () {
      final d = dataset([facilityJson(id: 'meal-1')]);
      final out = reconcileSavedPlaces([place('meal-1'), place('meal-old')], d);
      expect(out.map((p) => p.id), ['meal-1']);
    });
  });

  group('화면용 정렬', () {
    final open = facilityJson(id: 'open', name: '열린 곳', lat: 37.60, lng: 126.98);
    final closedNear = facilityJson(id: 'closed-near', name: '닫힌 가까운 곳', lat: 37.561, lng: 126.981, hours: [
      {'days': ['mon'], 'open': '17:00', 'close': '18:00'},
    ]);
    final closedFar = facilityJson(id: 'closed-far', name: '닫힌 먼 곳', lat: 37.65, lng: 126.98, hours: [
      {'days': ['mon'], 'open': '17:00', 'close': '18:00'},
    ]);
    final expired = facilityJson(id: 'expired', name: '오래된 곳', lastVerified: '2026-01-01', lat: 37.5601, lng: 126.9801);
    const origin = GeoPoint(37.56, 126.98);

    test('지금 열린 곳 → 닫힌 곳(가까운 순) → 오래된 정보 → 못 찾은 곳', () {
      final d = dataset([open, closedNear, closedFar, expired]);
      final saved = [place('gone'), place('expired'), place('closed-far'), place('closed-near'), place('open')];
      final out = savedEntries(saved, d, now: now, origin: origin);
      expect(out.map((e) => e.saved.id), ['open', 'closed-near', 'closed-far', 'expired', 'gone']);
      expect(out.last.missing, isTrue);
      expect(out.first.current!.distance, isNotNull);
    });

    test('기준 위치가 없으면 거리 없이, 같은 묶음 안은 저장한 순', () {
      final d = dataset([closedNear, closedFar]);
      final out = savedEntries([place('closed-far'), place('closed-near')], d, now: now);
      expect(out.map((e) => e.saved.id), ['closed-far', 'closed-near']);
      expect(out.first.current!.distance, isNull);
    });

    test('못 찾은 곳에는 같은 분류·같은 이름 시설을 비슷한 곳으로', () {
      final d = dataset([
        facilityJson(id: 'moved', name: '사랑 급식소', address: '서울 중구 새주소 5'),
        facilityJson(id: 'busan', name: '사랑 급식소', address: '부산 중구 1', sido: '부산'),
        facilityJson(id: 'shelter', name: '사랑 급식소', category: 'shelter'),
      ]);
      final out = savedEntries([place('gone', name: '사랑급식소', address: '서울 중구 옛주소 1')], d, now: now);
      expect(out.single.missing, isTrue);
      expect(out.single.similar.map((f) => f.id), ['moved'], reason: '다른 시도·다른 분류는 빼기');
    });

    test('확인 안 된 공공데이터 시간은 "열림"으로 앞에 두지 않는다', () {
      final d = dataset([
        facilityJson(id: 'public', verifiedBy: 'public_data', lat: 37.5601, lng: 126.9801),
        facilityJson(id: 'verified', lat: 37.61, lng: 126.98),
      ]);
      final out = savedEntries([place('public'), place('verified')], d, now: now, origin: origin);
      expect(out.map((e) => e.saved.id), ['verified', 'public']);
    });
  });
}
