import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majung/domain/geo.dart';
import 'package:majung/services/location_service.dart';

import 'harness.dart';

void main() {
  group('홈', () {
    testWidgets('1차 범위 카테고리 두 개와 열린 곳 개수, 긴급 버튼', (tester) async {
      await Harness().pump(tester);
      expect(find.text('밥 먹을 곳'), findsOneWidget);
      expect(find.text('잘 곳'), findsOneWidget);
      expect(find.text('씻을 곳 · 빨래'), findsNothing, reason: '1차 범위 밖');
      // 밥: 열린 급식소 + 오래된 급식소(같은 운영시간) = 2, 잠자리: 1
      expect(find.text('모두 3곳 · 지금 열림 2곳'), findsOneWidget);
      expect(find.text('모두 1곳 · 지금 열림 1곳'), findsOneWidget);
      expect(find.text('급할 때 전화하기'), findsOneWidget);
      expect(find.text('가까운 순으로 보려면 위치를 정해 주세요'), findsOneWidget);
    });

    testWidgets('저장된 기준 장소를 기억한다', (tester) async {
      await Harness(savedLandmark: 'yeongdeungpo').pump(tester);
      expect(find.text('영등포역 근처 기준'), findsOneWidget);
    });

    testWidgets('앱 시작 시 위치 권한을 묻지 않는다', (tester) async {
      final h = Harness();
      await h.pump(tester);
      expect(h.location.requests, 0);
    });
  });

  group('목록', () {
    testWidgets('열린 곳이 먼저, 상태와 대상, 전화 버튼', (tester) async {
      final h = Harness();
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();

      expect(find.text('운영 시간은 바뀔 수 있어요. 가기 전에 전화로 꼭 확인하세요.'), findsOneWidget);
      final openY = tester.getTopLeft(find.byKey(const Key('facility-meal-open'))).dy;
      final closedFinder = find.byKey(const Key('facility-meal-closed'));
      await scrollTo(tester, closedFinder);
      expect(find.textContaining('오늘 오후 5시에 열어요'), findsOneWidget);
      expect(find.text('전화번호 없음'), findsOneWidget);

      await tester.scrollUntilVisible(find.byKey(const Key('facility-meal-open')), -200,
          scrollable: find.byType(Scrollable).first);
      expect(openY, lessThan(tester.getTopLeft(closedFinder).dy + 10000));
      expect(find.textContaining('지금 열려 있어요'), findsWidgets);
      expect(find.textContaining('오후 1시까지'), findsWidgets);

      await tester.tap(find.descendant(of: find.byKey(const Key('facility-meal-open')), matching: find.text('전화')));
      expect(h.launcher.dialed, ['02-111-1111']);
    });

    testWidgets('오래된 정보는 경고를 보여준다', (tester) async {
      await Harness(facilities: [mealStale]).pump(tester);
      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();
      expect(find.text('정보가 오래됐을 수 있어요. 가기 전에 전화로 확인하세요.'), findsOneWidget);
    });

    testWidgets('데이터가 없으면 안내', (tester) async {
      await Harness(facilities: []).pump(tester);
      await tester.tap(find.byKey(const Key('group-sleep')));
      await tester.pumpAndSettle();
      expect(find.text('아직 등록된 곳이 없어요.'), findsOneWidget);
      expect(find.text('급할 때 전화하기'), findsOneWidget);
    });

    testWidgets('전화 앱을 열 수 없으면 알려준다', (tester) async {
      final h = Harness(facilities: [mealOpen]);
      h.launcher.succeed = false;
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('전화'));
      await tester.pumpAndSettle();
      expect(find.text('열 수 있는 앱이 없어요'), findsOneWidget);
    });
  });

  group('기준 위치', () {
    testWidgets('위치 거부 → 안내 문구, 랜드마크 선택 → 거리 표시', (tester) async {
      final h = Harness(facilities: [mealOpen]);
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('origin-bar')));
      await tester.pumpAndSettle();
      expect(find.textContaining('위치는 휴대폰 밖으로 보내지 않아요'), findsOneWidget);

      await tester.tap(find.byKey(const Key('use-gps')));
      await tester.pumpAndSettle();
      expect(h.location.requests, 1);
      expect(find.text('위치를 쓸 수 없어요. 아래에서 가까운 곳을 골라 주세요.'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('landmark-seoul_station')));
      expect(find.text('서울역 근처 기준'), findsOneWidget);
      expect(h.originStore.id, 'seoul_station');

      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();
      expect(find.textContaining('걸어서 약'), findsOneWidget);
    });

    testWidgets('권한 영구 거부면 설정 열기 버튼', (tester) async {
      final h = Harness(location: const LocationResult.failed(LocationFailure.deniedForever));
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('origin-bar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('use-gps')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('설정 열기'));
      expect(h.location.settingsOpened, isTrue);
    });

    testWidgets('GPS 성공 → 내 위치 기준, 좌표는 저장하지 않음', (tester) async {
      final h = Harness(
        location: const LocationResult.success(GeoPoint(37.5550, 126.9710)),
        savedLandmark: 'euljiro',
      );
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('origin-bar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('use-gps')));
      await tester.pumpAndSettle();
      expect(find.text('내 위치 기준'), findsOneWidget);
      expect(h.originStore.id, isNull);
    });
  });

  group('상세', () {
    testWidgets('운영시간 표, 대상, 조건, 참고, 전화·길찾기', (tester) async {
      final h = Harness(facilities: [mealOpen]);
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('자세히'));
      await tester.pumpAndSettle();

      expect(find.text('열린 급식소'), findsOneWidget);
      expect(find.text('월~금 (오늘)'), findsOneWidget);
      expect(find.text('오전 11시 30분 ~ 오후 1시'), findsOneWidget);
      expect(find.text('토·일'), findsOneWidget);
      expect(find.text('쉬어요'), findsOneWidget);
      await scrollTo(tester, find.text('신분증 없어도 됨'), within: const Key('detail'));
      expect(find.text('셋째 주 수요일 쉼'), findsOneWidget);
      expect(find.text('누구나'), findsOneWidget);
      expect(find.text('마지막 확인: 2026년 10월 1일'), findsOneWidget);
      expect(find.textContaining('테스트 데이터'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('detail-call')), within: const Key('detail'));
      expect(h.launcher.dialed, ['02-111-1111']);
      await tapVisible(tester, find.byKey(const Key('detail-directions')), within: const Key('detail'));
      expect(h.launcher.directionsTo, ['열린 급식소']);
    });

    testWidgets('신고 이메일이 없으면 신고 버튼 숨김, 있으면 표시', (tester) async {
      await Harness(facilities: [mealOpen]).pump(tester);
      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('자세히'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-report')), findsNothing);
    });

    testWidgets('신고 버튼은 시설 이름을 담아 메일을 연다', (tester) async {
      final h = Harness(facilities: [mealOpen], reportEmail: 'report@example.org');
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('자세히'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('detail-report')), within: const Key('detail'));
      expect(h.launcher.emails, ['report@example.org|[마중 정보 오류] 열린 급식소']);
    });
  });

  group('지도', () {
    testWidgets('핀을 누르면 요약 카드', (tester) async {
      await Harness(facilities: [mealOpen]).pump(tester);
      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('toggle-map')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('map')), findsOneWidget);
      expect(find.text('목록으로 보기'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pin-meal-open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('map-selected')), findsOneWidget);
      expect(find.text('© OpenStreetMap'), findsOneWidget);
    });
  });

  testWidgets('긴급 전화: 노숙인 위기대응콜', (tester) async {
    final h = Harness();
    await h.pump(tester);
    await tester.tap(find.byKey(const Key('emergency')));
    await tester.pumpAndSettle();
    expect(find.text('1600-9582'), findsOneWidget);
    await tester.tap(find.byKey(const Key('call-1600-9582')));
    expect(h.launcher.dialed, ['1600-9582']);
    for (final n in ['129', '109', '120', '112', '119']) {
      await tester.scrollUntilVisible(find.byKey(Key('call-$n')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text(n), findsOneWidget);
    }
  });

  testWidgets('앱 정보: 민간 앱 안내, 개인정보, 출처', (tester) async {
    await Harness().pump(tester);
    await tester.tap(find.byTooltip('앱 정보'));
    await tester.pumpAndSettle();
    expect(find.textContaining('정부나 구청이 만든 앱이 아니고'), findsOneWidget);
    expect(find.textContaining('위치는 가까운 순서를 계산할 때 휴대폰 안에서만'), findsOneWidget);
    expect(find.textContaining('공공누리 1유형'), findsOneWidget);
  });

  group('접근성', () {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('글자 크기 ${scale}배에서 모든 화면이 깨지지 않음', (tester) async {
        final h = Harness(reportEmail: 'report@example.org');
        await h.pump(tester, textScale: scale);
        // 넘침(overflow)은 테스트 예외로 잡힌다.
        await tapVisible(tester, find.byKey(const Key('group-meal')));
        await tapVisible(tester, find.byKey(const Key('facility-meal-open')));
        expect(find.byKey(const Key('detail')), findsOneWidget);
        await goBack(tester);
        await goBack(tester);
        await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, 2000));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('origin-bar')));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('emergency')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('다크 모드', (tester) async {
      await Harness().pump(tester, brightness: Brightness.dark);
      expect(Theme.of(tester.element(find.text('밥 먹을 곳'))).brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
    });

    testWidgets('주요 버튼은 48dp 이상', (tester) async {
      await Harness(facilities: [mealOpen]).pump(tester);
      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets('글자 대비 (WCAG AA)', (tester) async {
      await Harness(facilities: [mealOpen, mealClosed]).pump(tester);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  });
}
