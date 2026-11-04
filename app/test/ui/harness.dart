import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majung/app.dart';
import 'package:majung/app_controller.dart';
import 'package:majung/config.dart';
import 'package:majung/data/facility_repository.dart';
import 'package:majung/domain/geo.dart';
import 'package:majung/domain/region.dart';
import 'package:majung/domain/saved_places.dart';
import 'package:majung/services/launcher.dart';
import 'package:majung/services/location_service.dart';

import '../fixtures.dart';

class FakeLauncher implements ActionLauncher {
  final dialed = <String>[];
  final directionsTo = <String>[];
  final emails = <String>[];
  bool succeed = true;

  @override
  Future<bool> dial(String phone) async {
    dialed.add(phone);
    return succeed;
  }

  @override
  Future<bool> directions(String name, GeoPoint destination) async {
    directionsTo.add(name);
    return succeed;
  }

  @override
  Future<bool> email(String to, {required String subject, required String body}) async {
    emails.add('$to|$subject');
    return succeed;
  }

  @override
  Future<bool> openWeb(Uri url) async => succeed;
}

class FakeLocation implements LocationService {
  FakeLocation([this.result = const LocationResult.failed(LocationFailure.denied)]);
  LocationResult result;
  int requests = 0;
  bool settingsOpened = false;

  @override
  Future<LocationResult> current() async {
    requests++;
    return result;
  }

  @override
  Future<void> openSettings() async => settingsOpened = true;
}

/// 월요일 12:00 (점심 급식 운영 중).
final testNow = DateTime(2026, 11, 2, 12);

final mealOpen = facilityJson(
  id: 'meal-open',
  name: '열린 급식소',
  lat: 37.5552,
  lng: 126.9712,
  phone: '02-111-1111',
  requirements: '신분증 없어도 됨',
  hoursNote: '셋째 주 수요일 쉼',
);
final mealClosed = facilityJson(
  id: 'meal-closed',
  name: '저녁 급식소',
  phone: null,
  hours: [
    {'days': ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'], 'open': '17:00', 'close': '18:30'},
  ],
);
final mealStale = facilityJson(id: 'meal-stale', name: '오래된 급식소', lastVerified: '2026-06-01');
final shelter = facilityJson(
  id: 'shelter-1',
  name: '테스트 쉼터',
  category: 'shelter',
  hours: [
    {'days': ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'], 'open': '00:00', 'close': '24:00'},
  ],
);

class Harness {
  Harness({
    List<Map<String, dynamic>>? facilities,
    LocationResult? location,
    String? reportEmail,
    // 기본은 서울 중구를 골라 둔 상태. 위치를 안 정한 상태는 savedRegion: null.
    String? savedRegion = seoulJunggu,
    List<SavedPlace> saved = const [],
  })  : launcher = FakeLauncher(),
        location = FakeLocation(location ?? const LocationResult.failed(LocationFailure.denied)),
        originStore = MemoryOriginStore(savedRegion),
        savedStore = MemorySavedPlacesStore(saved),
        config = AppConfig(reportEmail: reportEmail, tileUrlTemplate: null) {
    final json = jsonEncode(datasetJson(facilities: facilities ?? [mealOpen, mealClosed, mealStale, shelter]));
    controller = AppController(
      repository: FacilityRepository(loadBundled: () async => json, cache: MemoryDatasetCache()),
      location: this.location,
      originStore: originStore,
      savedStore: savedStore,
      loadRegions: () async => RegionCatalog.fromJson(regionsJson()),
      clock: () => testNow,
      tick: null,
    );
  }

  final FakeLauncher launcher;
  final FakeLocation location;
  final MemoryOriginStore originStore;
  final MemorySavedPlacesStore savedStore;
  final AppConfig config;
  late final AppController controller;

  Future<void> pump(WidgetTester tester, {double textScale = 1.0, Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await controller.start();
    await tester.pumpWidget(MajungApp(controller: controller, launcher: launcher, config: config));
    await tester.pumpAndSettle();
  }
}

/// 화면의 주 스크롤 영역을 내려서 [finder]가 보이게 한다(아직 안 그려진 항목 포함).
Future<void> scrollTo(WidgetTester tester, Finder finder, {Key? within}) async {
  final scrollable = within == null
      ? find.byType(Scrollable).hitTestable().first
      : find.descendant(of: find.byKey(within), matching: find.byType(Scrollable)).first;
  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder);
  } else {
    // 아래로 찾아보고, 없으면(이미 지나쳤으면) 위로.
    try {
      await tester.scrollUntilVisible(finder, 300, scrollable: scrollable, maxScrolls: 30);
    } on StateError {
      await tester.scrollUntilVisible(finder, -300, scrollable: scrollable, maxScrolls: 60);
    }
  }
  await tester.pumpAndSettle();
}

/// 스크롤해서 보이게 한 뒤 탭.
Future<void> tapVisible(WidgetTester tester, Finder finder, {Key? within}) async {
  await scrollTo(tester, finder, within: within);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 앱바의 뒤로 버튼(한국어 툴팁 '뒤로')을 누른다.
Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('뒤로').last);
  await tester.pumpAndSettle();
}
