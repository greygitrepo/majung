import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:majung/app.dart';
import 'package:majung/app_controller.dart';
import 'package:majung/config.dart';
import 'package:majung/data/facility_repository.dart';
import 'package:majung/domain/category.dart';
import 'package:majung/domain/region.dart';
import 'package:path_provider/path_provider.dart';

import '../test/ui/harness.dart' show FakeLauncher, FakeLocation;

/// README 스크린샷(docs/screenshots/shot-*.png)을 다시 찍는다. 실제 앱 데이터·실제 지도 타일을 쓴다.
///
///   docker compose run --rm -w /workspace/app emulator bash -c "start-emulator && \
///     flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshots_test.dart -d emulator-5554"
///
/// 시각은 README 설명과 같은 2026-11-04(수) 낮 12시 20분으로 고정한다.
/// 1~5: 서울 중구 (첫 화면에 저장한 곳 3곳), 6~8: 부산 중구.
final shotTime = DateTime(2026, 11, 4, 12, 20);
const seoulJunggu = '11140';
const busanJunggu = '26110';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  /// 지도 타일이 내려올 시간을 준다 (pumpAndSettle 은 네트워크를 기다리지 않음).
  Future<void> waitTiles(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('README 스크린샷', (tester) async {
    // 고른 지역만 실제 저장소에 둔다. 저장한 곳은 메모리에만 (기기의 실제 저장값을 건드리지 않음).
    await PrefsOriginStore().saveRegionCode(seoulJunggu);
    final dir = await getApplicationSupportDirectory();
    final cache = File('${dir.path}/screenshots-facilities.json');
    if (cache.existsSync()) cache.deleteSync();

    final controller = AppController(
      repository: FacilityRepository(
        loadBundled: () => rootBundle.loadString('assets/data/facilities.json'),
        cache: FileDatasetCache(cache),
      ),
      location: FakeLocation(),
      originStore: PrefsOriginStore(),
      savedStore: MemorySavedPlacesStore(),
      loadRegions: () async =>
          RegionCatalog.fromJson(jsonDecode(await rootBundle.loadString('assets/data/regions.json'))),
      clock: () => shotTime,
      tick: null,
    );
    await controller.start();

    // 첫 화면에 보일 저장한 곳: 밥 2곳 + 잠자리 1곳 (가까운 순 맨 위).
    for (final r in [
      ...controller.ranked(CategoryGroup.meal).take(2),
      ...controller.ranked(CategoryGroup.sleep).take(1),
    ]) {
      await controller.toggleSaved(r.facility);
    }

    await tester.pumpWidget(MajungApp(
      controller: controller,
      launcher: FakeLauncher(),
      config: const AppConfig(),
    ));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();

    Future<void> back() async {
      await tester.tap(find.byTooltip('뒤로').last);
      await tester.pumpAndSettle();
    }

    await shot(tester, 'shot-1-home');

    await tester.tap(find.byKey(const Key('origin-bar')));
    await shot(tester, 'shot-2-picker');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(const Key('group-meal')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('group-meal')));
    await shot(tester, 'shot-3-meal-list');

    await tester.tap(find.text('자세히').first);
    await shot(tester, 'shot-4-detail');
    await back();
    await back();

    await tester.scrollUntilVisible(find.byKey(const Key('group-clinic')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('group-clinic')));
    await shot(tester, 'shot-5-clinic');
    await back();

    final busan = controller.regions.byCode(busanJunggu);
    expect(busan, isNotNull, reason: 'regions.json 에 부산 중구가 있어야 함');
    await controller.useRegion(busan!);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('group-meal')), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('group-meal')));
    await shot(tester, 'shot-6-busan-list');

    await tester.tap(find.byKey(const Key('toggle-map')));
    await tester.pumpAndSettle();
    await waitTiles(tester);
    await shot(tester, 'shot-7-busan-map');
    await back();

    await tester.tap(find.byKey(const Key('emergency')));
    await shot(tester, 'shot-8-emergency');
  });
}
