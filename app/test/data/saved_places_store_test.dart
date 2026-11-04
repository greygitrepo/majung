import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:majung/app_controller.dart';
import 'package:majung/data/facility_repository.dart';
import 'package:majung/domain/category.dart';
import 'package:majung/domain/region.dart';
import 'package:majung/domain/saved_places.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures.dart';
import '../ui/harness.dart' show FakeLocation;

SavedPlace place(String id, {String name = '테스트 급식소'}) => SavedPlace(
      id: id,
      name: name,
      category: FacilityCategory.meal,
      address: '서울 중구 테스트로 1',
      phone: '02-000-0000',
      savedAt: DateTime(2026, 11, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrefsSavedPlacesStore', () {
    test('저장하고 다시 읽는다', () async {
      SharedPreferences.setMockInitialValues({});
      final store = PrefsSavedPlacesStore();
      await store.save([place('a'), place('b')]);
      expect((await store.load()).map((p) => p.id), ['a', 'b']);
    });

    test('깨진 저장값이면 빈 목록', () async {
      SharedPreferences.setMockInitialValues({'saved_places_v1': '{{깨짐'});
      expect(await PrefsSavedPlacesStore().load(), isEmpty);
    });

    test('모두 지우면 저장값도 지운다', () async {
      SharedPreferences.setMockInitialValues({});
      final store = PrefsSavedPlacesStore();
      await store.save([place('a')]);
      await store.save(const []);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('saved_places_v1'), isFalse);
    });

    test('고른 지역 저장값과 섞이지 않는다', () async {
      SharedPreferences.setMockInitialValues({'origin_region': '11140'});
      await PrefsSavedPlacesStore().save([place('a')]);
      expect(await PrefsOriginStore().loadRegionCode(), '11140');
    });
  });

  group('AppController 저장한 곳', () {
    AppController controller(MemorySavedPlacesStore store, List<Map<String, dynamic>> facilities) {
      final json = jsonEncode(datasetJson(facilities: facilities));
      return AppController(
        repository: FacilityRepository(loadBundled: () async => json, cache: MemoryDatasetCache()),
        location: FakeLocation(),
        originStore: MemoryOriginStore(seoulJunggu),
        savedStore: store,
        loadRegions: () async => RegionCatalog.fromJson(regionsJson()),
        clock: () => DateTime(2026, 11, 2, 12),
        tick: null,
      );
    }

    test('저장·빼기·모두 지우기가 저장소에 바로 남는다', () async {
      final store = MemorySavedPlacesStore();
      final c = controller(store, [facilityJson(id: 'a', name: '가'), facilityJson(id: 'b', name: '나')]);
      await c.start();
      final a = c.dataset!.facilities.firstWhere((f) => f.id == 'a');
      final b = c.dataset!.facilities.firstWhere((f) => f.id == 'b');

      expect(await c.toggleSaved(a), isTrue);
      expect(await c.toggleSaved(b), isTrue);
      expect(store.places.map((p) => p.id), ['b', 'a'], reason: '최근 저장이 앞');
      expect(c.isSaved('a'), isTrue);

      expect(await c.toggleSaved(a), isFalse);
      expect(store.places.map((p) => p.id), ['b']);

      await c.clearSaved();
      expect(store.places, isEmpty);
      expect(c.savedEntriesNow(), isEmpty);
    });

    test('시작할 때 ID가 바뀐 시설을 다시 찾아 저장해 둔다', () async {
      final store = MemorySavedPlacesStore([place('old-id', name: '사랑 급식소')]);
      final c = controller(store, [facilityJson(id: 'new-id', name: '사랑급식소')]);
      await c.start();
      expect(c.saved.single.id, 'new-id');
      expect(store.places.single.id, 'new-id');
      expect(c.savedEntriesNow().single.missing, isFalse);
    });

    test('바뀐 게 없으면 시작할 때 다시 쓰지 않는다', () async {
      final store = MemorySavedPlacesStore([place('a')]);
      final c = controller(store, [facilityJson(id: 'a')]);
      await c.start();
      expect(store.saves, 0);
    });

    test('저장소가 실패해도 앱은 계속 돈다', () async {
      final c = AppController(
        repository: FacilityRepository(
          loadBundled: () async => jsonEncode(datasetJson()),
          cache: MemoryDatasetCache(),
        ),
        location: FakeLocation(),
        originStore: MemoryOriginStore(),
        savedStore: _BrokenStore(),
        tick: null,
      );
      await c.start();
      expect(c.ready, isTrue);
      expect(c.saved, isEmpty);
      expect(await c.toggleSaved(c.dataset!.facilities.single), isTrue, reason: '이번 실행 동안은 남는다');
    });
  });
}

class _BrokenStore implements SavedPlacesStore {
  @override
  Future<List<SavedPlace>> load() async => throw StateError('읽기 실패');
  @override
  Future<void> save(List<SavedPlace> places) async => throw StateError('쓰기 실패');
}
