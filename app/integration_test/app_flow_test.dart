import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:majung/app.dart';
import 'package:majung/app_controller.dart';
import 'package:majung/config.dart';
import 'package:majung/data/facility_repository.dart';
import 'package:majung/domain/geo.dart';
import 'package:majung/services/location_service.dart';
import 'package:path_provider/path_provider.dart';

import '../test/ui/harness.dart' show FakeLauncher, FakeLocation;

/// 실제 기기(에뮬레이터)에서: 실제 앱 데이터 파일, 실제 파일 저장소, 실제 SharedPreferences.
/// 전화·지도 앱을 실제로 열면 테스트가 앱을 벗어나므로 그 부분만 가짜로 바꾼다.
Future<({FakeLauncher launcher, FakeLocation location, AppController controller})> launch(
  WidgetTester tester, {
  LocationResult location = const LocationResult.failed(LocationFailure.denied),
  Uri? dataUrl,
}) async {
  final dir = await getApplicationSupportDirectory();
  final cacheFile = File('${dir.path}/facilities.json');
  final launcher = FakeLauncher();
  final fakeLocation = FakeLocation(location);
  final controller = AppController(
    repository: FacilityRepository(
      loadBundled: () => rootBundle.loadString('assets/data/facilities.json'),
      cache: FileDatasetCache(cacheFile),
      remoteUrl: dataUrl,
    ),
    location: fakeLocation,
    originStore: PrefsOriginStore(),
    tick: null,
  );
  await controller.start();
  await tester.pumpWidget(MajungApp(
    controller: controller,
    launcher: launcher,
    config: const AppConfig(tileUrlTemplate: null, reportEmail: 'report@example.org'),
  ));
  await tester.pumpAndSettle();
  return (launcher: launcher, location: fakeLocation, controller: controller);
}

/// 이미 그려진 위젯은 ensureVisible, 아직 안 그려졌으면 [within] 스크롤을 내려서 찾는다.
Future<void> scrollToAndTap(WidgetTester tester, Finder finder, {Key? within}) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = within == null
        ? find.byType(Scrollable).last
        : find.descendant(of: find.byKey(within), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(finder, 300, scrollable: scrollable);
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await PrefsOriginStore().saveLandmarkId(null);
  });

  testWidgets('핵심 흐름: 홈 → 밥 먹을 곳 → 상세 → 전화·길찾기', (tester) async {
    final app = await launch(tester);
    expect(find.text('밥 먹을 곳'), findsOneWidget);
    expect(find.text('잘 곳'), findsOneWidget);

    await tester.tap(find.byKey(const Key('group-meal')));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsWidgets);

    final firstCard = find.byType(Card).first;
    await tester.tap(find.descendant(of: firstCard, matching: find.text('자세히')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail')), findsOneWidget);
    expect(find.text('언제 가면 되나요'), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail-directions')));
    await tester.pumpAndSettle();
    expect(app.launcher.directionsTo, hasLength(1));
  });

  testWidgets('위치 권한 거부 → 서울역 선택 → 거리 표시, 다시 켜도 기억', (tester) async {
    await launch(tester);
    await tester.tap(find.byKey(const Key('origin-bar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('use-gps')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-failure')), findsOneWidget);
    await scrollToAndTap(tester, find.byKey(const Key('landmark-seoul_station')));
    expect(find.text('서울역 근처 기준'), findsOneWidget);

    await tester.tap(find.byKey(const Key('group-meal')));
    await tester.pumpAndSettle();
    expect(find.textContaining('걸어서 약'), findsWidgets);

    // 앱을 새로 띄운 것처럼 다시 시작 → SharedPreferences 에 저장된 기준 장소
    await tester.pumpWidget(const SizedBox());
    await launch(tester);
    expect(find.text('서울역 근처 기준'), findsOneWidget);
  });

  testWidgets('GPS 위치 사용', (tester) async {
    await launch(tester, location: const LocationResult.success(GeoPoint(37.5156, 126.9073)));
    await tester.tap(find.byKey(const Key('origin-bar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('use-gps')));
    await tester.pumpAndSettle();
    expect(find.text('내 위치 기준'), findsOneWidget);
  });

  testWidgets('오프라인: 데이터 서버에 닿지 않아도 앱 데이터로 동작', (tester) async {
    // 존재하지 않는 주소 → 업데이트 실패 → 기존 데이터 유지
    final app = await launch(tester, dataUrl: Uri.parse('https://invalid.invalid/facilities.json'));
    expect(await app.controller.refresh(), UpdateResult.failed);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('group-sleep')));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('긴급 전화와 지도 화면', (tester) async {
    final app = await launch(tester);
    await tester.tap(find.byKey(const Key('emergency')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('call-1600-9582')));
    expect(app.launcher.dialed, ['1600-9582']);
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('group-sleep')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('toggle-map')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map')), findsOneWidget);
    expect(find.text('© OpenStreetMap'), findsOneWidget);
  });

  testWidgets('글자 크기 200%', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await launch(tester);
    await scrollToAndTap(tester, find.byKey(const Key('group-meal')));
    expect(find.byKey(const Key('facility-list')), findsOneWidget, reason: '목록 화면으로 이동해야 함');
    await scrollToAndTap(tester, find.widgetWithText(OutlinedButton, '자세히'), within: const Key('facility-list'));
    expect(find.byKey(const Key('detail')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
