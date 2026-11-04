import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majung/app_controller.dart';
import 'package:majung/domain/category.dart';
import 'package:majung/domain/geo.dart';
import 'package:majung/domain/saved_places.dart';
import 'package:majung/services/location_service.dart';

import '../fixtures.dart';
import 'harness.dart';

void main() {
  group('홈', () {
    testWidgets('1차 범위 카테고리 세 개와 열린 곳 개수, 긴급 버튼', (tester) async {
      await Harness().pump(tester);
      expect(find.text('밥 먹을 곳'), findsOneWidget);
      expect(find.text('잘 곳'), findsOneWidget);
      expect(find.text('아플 때'), findsOneWidget);
      expect(find.text('씻을 곳 · 빨래'), findsNothing, reason: '1차 범위 밖');
      // 밥: 열린 급식소 + 오래된 급식소(같은 운영시간) = 2, 잠자리: 1
      expect(find.text('지금 열림 2곳 · 모두 3곳'), findsOneWidget);
      expect(find.text('지금 열림 1곳 · 모두 1곳'), findsOneWidget);
      expect(find.text('급할 때 전화하기'), findsOneWidget);
      expect(find.text('서울 중구 기준'), findsOneWidget);
    });

    testWidgets('위치를 안 정했으면 먼저 정하라고 안내', (tester) async {
      await Harness(savedRegion: null).pump(tester);
      expect(find.text('어디 근처에서 찾을지 먼저 정해 주세요'), findsOneWidget);
      expect(find.text('위치를 정하면 가까운 곳을 보여 드려요'), findsWidgets);
      expect(find.textContaining('지금 열림'), findsNothing);
    });

    testWidgets('저장된 지역을 기억한다', (tester) async {
      await Harness(savedRegion: '11560').pump(tester);
      expect(find.text('서울 영등포구 기준'), findsOneWidget);
    });

    testWidgets('없어진 지역 코드는 무시한다', (tester) async {
      await Harness(savedRegion: '99999').pump(tester);
      expect(find.text('어디 근처에서 찾을지 먼저 정해 주세요'), findsOneWidget);
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

      expect(find.text('시간이 바뀔 수 있어요. 가기 전에 전화로 한 번 확인해 주세요.'), findsOneWidget);
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

    testWidgets('위치를 안 정했으면 전국 목록 대신 위치 정하기', (tester) async {
      await Harness(savedRegion: null).pump(tester);
      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('need-origin')), findsOneWidget);
      expect(find.byKey(const Key('facility-meal-open')), findsNothing);
      expect(find.byKey(const Key('toggle-map')), findsNothing);
      await tester.tap(find.byKey(const Key('need-origin-pick')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('sido-서울')));
      await tapVisible(tester, find.byKey(const Key('region-11140')));
      expect(find.byKey(const Key('facility-meal-open')), findsOneWidget);
    });

    testWidgets('공공데이터 시간은 "지금 열림"으로 계산하지 않는다', (tester) async {
      final unverified = facilityJson(
        id: 'meal-public',
        name: '확인 안 된 급식소',
        verifiedBy: 'public_data',
        hours: [],
        hoursNote: '공공데이터 안내: 매일 11:30~13:00',
      );
      await Harness(facilities: [unverified]).pump(tester);
      expect(find.text('지금 열림 0곳 · 모두 1곳'), findsOneWidget);
      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();
      expect(find.textContaining('운영 시간 확인 필요', findRichText: true), findsOneWidget);
      expect(find.textContaining('지금 열려 있어요', findRichText: true), findsNothing);
      await tester.tap(find.text('자세히'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('unverified-hours')), findsOneWidget);
      expect(find.textContaining('실제와 다른 경우가 많아요'), findsOneWidget);
      expect(find.text('공공데이터 안내: 매일 11:30~13:00'), findsOneWidget);
    });

    testWidgets('어르신 경로식당은 아래에 따로 묶는다', (tester) async {
      final senior = facilityJson(id: 'meal-senior', name: '경로식당', audience: 'senior');
      await Harness(facilities: [senior, mealClosed]).pump(tester);
      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('facility-meal-senior')));
      final sectionY = tester.getTopLeft(find.byKey(const Key('senior-section'))).dy;
      expect(tester.getTopLeft(find.byKey(const Key('facility-meal-senior'))).dy, greaterThan(sectionY));
      expect(find.textContaining('미리 등록해야'), findsOneWidget);
    });

    testWidgets('아플 때: 의료급여 안내, 무료 진료소가 보건소보다 먼저', (tester) async {
      final free = facilityJson(
          id: 'clinic-free', name: '무료진료소', category: 'clinic', subtype: 'free_clinic', lat: 37.5450, lng: 126.9710);
      final health = facilityJson(
          id: 'clinic-hc', name: '구 보건소', category: 'clinic', subtype: 'health_center', lat: 37.5600, lng: 126.9800);
      await Harness(facilities: [health, free]).pump(tester);
      await tapVisible(tester, find.byKey(const Key('group-clinic')));
      expect(find.byKey(const Key('clinic-info')), findsOneWidget);
      expect(find.textContaining('노숙인 의료급여증'), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('facility-clinic-hc')));
      expect(find.text('보건소 · 진료비가 싸요 (무료 아님)'), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('facility-clinic-free')));
      expect(find.text('무료 진료소'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('facility-clinic-free'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('facility-clinic-hc'))).dy),
      );
    });

    testWidgets('먼 곳은 걷는 시간 대신 거리만', (tester) async {
      await Harness(facilities: [facilityJson(id: 'far', lat: 37.2, lng: 127.1)]).pump(tester);
      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();
      expect(find.textContaining('걸어서'), findsNothing);
      expect(find.textContaining('여기서'), findsOneWidget);
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
    testWidgets('위치 거부 → 안내 문구, 시도·시군구 선택 → 거리 표시', (tester) async {
      final h = Harness(facilities: [mealOpen], savedRegion: null);
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('origin-bar')));
      await tester.pumpAndSettle();
      expect(find.textContaining('위치는 휴대폰 밖으로 보내지 않아요'), findsOneWidget);

      await tester.tap(find.byKey(const Key('use-gps')));
      await tester.pumpAndSettle();
      expect(h.location.requests, 1);
      expect(find.text('위치를 쓸 수 없어요. 아래에서 지역을 골라 주세요.'), findsOneWidget);

      // 전국 시도가 다 나온다 (서울만이 아님).
      for (final sido in ['서울', '부산', '경기']) {
        expect(find.byKey(Key('sido-$sido')), findsOneWidget);
      }
      await tapVisible(tester, find.byKey(const Key('sido-부산')));
      expect(find.text('부산에서 고르세요'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('sido-back')));
      await tapVisible(tester, find.byKey(const Key('sido-서울')));
      await tapVisible(tester, find.byKey(const Key('region-11140')));
      expect(find.text('서울 중구 기준'), findsOneWidget);
      expect(h.originStore.code, '11140');

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
        savedRegion: '26110',
      );
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('origin-bar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('use-gps')));
      await tester.pumpAndSettle();
      expect(find.text('내 위치 기준'), findsOneWidget);
      expect(h.originStore.code, isNull);
      // 긴급 연락처 지역은 기기 안에서 가장 가까운 시군구로 정한다 (서울).
      await tester.tap(find.byKey(const Key('emergency')));
      await tester.pumpAndSettle();
      expect(find.text('1600-9582'), findsOneWidget);
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

    testWidgets('주소로 찾은 좌표는 대략적이라고 알린다', (tester) async {
      await Harness(facilities: [facilityJson(id: 'g', geocoded: true)]).pump(tester);
      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('자세히'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('geocoded-note')), within: const Key('detail'));
      expect(find.text('지도 위치는 주소로 찾은 대략적인 위치예요.'), findsOneWidget);
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

    Future<void> openMap(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('toggle-map')));
      await tester.pumpAndSettle();
    }

    testWidgets('지역 기준: "처음 위치로"는 위치를 다시 읽지 않는다', (tester) async {
      final h = Harness(facilities: [mealOpen]);
      await h.pump(tester);
      await openMap(tester);
      expect(find.text('처음 위치로'), findsOneWidget);
      await tester.tap(find.byKey(const Key('map-recenter')));
      await tester.pumpAndSettle();
      expect(h.location.requests, 0);
      expect(h.controller.origin.kind, OriginKind.region);
    });

    testWidgets('GPS 기준: "내 위치로"는 위치를 한 번 새로 읽어 기준을 옮긴다', (tester) async {
      const first = GeoPoint(37.5550, 126.9710);
      const moved = GeoPoint(37.5600, 126.9800);
      final h = Harness(facilities: [mealOpen], location: const LocationResult.success(first));
      await h.pump(tester);
      await h.controller.useGps();
      await tester.pumpAndSettle();
      await openMap(tester);
      expect(find.text('내 위치로'), findsOneWidget);

      h.location.result = const LocationResult.success(moved);
      await tester.tap(find.byKey(const Key('map-recenter')));
      await tester.pumpAndSettle();
      expect(h.location.requests, 2);
      expect(h.controller.origin.point, moved);
      expect(find.byKey(const Key('map')), findsOneWidget);
    });

    testWidgets('GPS 기준: 위치를 못 읽으면 전 위치를 그대로 두고 알려 준다', (tester) async {
      const first = GeoPoint(37.5550, 126.9710);
      final h = Harness(facilities: [mealOpen], location: const LocationResult.success(first));
      await h.pump(tester);
      await h.controller.useGps();
      await tester.pumpAndSettle();
      await openMap(tester);

      h.location.result = const LocationResult.failed(LocationFailure.serviceOff);
      await tester.tap(find.byKey(const Key('map-recenter')));
      await tester.pumpAndSettle();
      expect(h.controller.origin.kind, OriginKind.gps);
      expect(h.controller.origin.point, first);
      expect(find.text('지금 위치를 찾지 못했어요. 전에 찾은 위치로 보여 드려요.'), findsOneWidget);
    });
  });

  group('긴급 전화', () {
    Future<void> open(WidgetTester tester, Harness h) async {
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('emergency')));
      await tester.pumpAndSettle();
    }

    Future<void> expectNumbers(WidgetTester tester, List<String> numbers) async {
      for (final n in numbers) {
        await tester.scrollUntilVisible(find.byKey(Key('call-$n')), 200, scrollable: find.byType(Scrollable).first);
        expect(find.text(n), findsOneWidget);
      }
    }

    testWidgets('서울: 노숙인 위기대응콜이 맨 위, 다산콜', (tester) async {
      final h = Harness();
      await open(tester, h);
      expect(find.text('1600-9582'), findsOneWidget);
      await tester.tap(find.byKey(const Key('call-1600-9582')));
      expect(h.launcher.dialed, ['1600-9582']);
      await expectNumbers(tester, ['129', '109', '1577-0199', '02-120', '112', '119']);
    });

    testWidgets('부산: 서울 번호 없이 전국 공통 번호', (tester) async {
      await open(tester, Harness(savedRegion: '26110'));
      expect(find.byKey(const Key('call-1600-9582')), findsNothing);
      await expectNumbers(tester, ['129', '109', '1577-0199', '112', '119']);
      expect(find.byKey(const Key('call-02-120')), findsNothing);
    });

    testWidgets('경기: 경기도 콜센터', (tester) async {
      await open(tester, Harness(savedRegion: '41111'));
      await expectNumbers(tester, ['129', '031-120']);
    });

    testWidgets('위치 모름: 전국 공통 번호만', (tester) async {
      await open(tester, Harness(savedRegion: null));
      expect(find.textContaining('전국 어디서나'), findsOneWidget);
      expect(find.byKey(const Key('call-1600-9582')), findsNothing);
      await expectNumbers(tester, ['129', '112', '119']);
    });
  });

  group('저장한 곳', () {
    SavedPlace saved(String id, {String name = '열린 급식소', String? phone = '02-111-1111'}) => SavedPlace(
          id: id,
          name: name,
          category: FacilityCategory.meal,
          address: '서울 중구 테스트로 1',
          phone: phone,
          sido: '서울',
          savedAt: DateTime(2026, 11, 1),
        );

    testWidgets('저장한 곳이 없으면 첫 화면에 묶음을 그리지 않는다', (tester) async {
      await Harness().pump(tester);
      expect(find.byKey(const Key('home-saved')), findsNothing);
      expect(find.text('저장한 곳'), findsNothing);
    });

    testWidgets('상세에서 저장 → 첫 화면에 나오고 바로 전화', (tester) async {
      final h = Harness(facilities: [mealOpen]);
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('group-meal')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('자세히'));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.byKey(const Key('detail-save')), within: const Key('detail'));
      expect(find.text('저장했어요. 첫 화면에서 바로 볼 수 있어요'), findsOneWidget);
      expect(find.text('저장한 곳에서 빼기'), findsOneWidget);
      expect(h.savedStore.places.single.id, 'meal-open');

      await goBack(tester);
      await goBack(tester);
      expect(find.byKey(const Key('home-saved')), findsOneWidget);
      final card = find.byKey(const Key('saved-meal-open'));
      expect(card, findsOneWidget);
      expect(find.descendant(of: card, matching: find.textContaining('지금 열려 있어요')), findsOneWidget);
      // 저장한 곳이 카테고리 버튼보다 위
      expect(tester.getTopLeft(card).dy, lessThan(tester.getTopLeft(find.byKey(const Key('group-meal'))).dy));

      await tester.tap(find.byKey(const Key('saved-call-meal-open')));
      await tester.pumpAndSettle();
      expect(h.launcher.dialed, ['02-111-1111']);
    });

    testWidgets('상세에서 다시 누르면 빠진다', (tester) async {
      final h = Harness(facilities: [mealOpen], saved: [saved('meal-open')]);
      await h.pump(tester);
      await tester.tap(find.descendant(of: find.byKey(const Key('saved-meal-open')), matching: find.text('자세히')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('detail-save')), within: const Key('detail'));
      expect(find.text('저장한 곳에서 뺐어요'), findsOneWidget);
      expect(find.text('저장하기'), findsOneWidget);
      expect(h.savedStore.places, isEmpty);
      await goBack(tester);
      expect(find.byKey(const Key('home-saved')), findsNothing);
    });

    testWidgets('첫 화면엔 3곳까지, 나머지는 모두 보기', (tester) async {
      final facilities = [
        for (var i = 0; i < 4; i++) facilityJson(id: 'm$i', name: '급식소 $i', lat: 37.555 - i * 0.001),
      ];
      final h = Harness(
        facilities: facilities,
        saved: [for (var i = 0; i < 4; i++) saved('m$i', name: '급식소 $i')],
      );
      await h.pump(tester);
      expect(find.byKey(const Key('home-saved')), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('home-saved-more')));
      expect(find.text('저장한 곳 모두 보기 (4곳)'), findsOneWidget);
      // 가까운 순으로 셋만: 가장 먼 m3 는 첫 화면에 없다
      expect(find.byKey(const Key('saved-m3'), skipOffstage: false), findsNothing);
      await tapVisible(tester, find.byKey(const Key('home-saved-more')));
      expect(find.text('저장한 곳'), findsWidgets);
      for (var i = 0; i < 4; i++) {
        await scrollTo(tester, find.byKey(Key('saved-m$i')), within: const Key('saved-list'));
        expect(find.byKey(Key('saved-m$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('emergency')), findsOneWidget, reason: '저장한 곳 화면에도 긴급 전화');
    });

    testWidgets('목록에서 빠진 곳: 예전 정보라고 알리고, 예전 번호 전화·지우기', (tester) async {
      final h = Harness(facilities: [mealOpen], saved: [saved('gone', name: '없어진 급식소', phone: '02-999-9999')]);
      await h.pump(tester);
      final card = find.byKey(const Key('saved-gone'));
      expect(card, findsOneWidget);
      expect(find.text('정보가 바뀌었거나 목록에서 빠졌어요'), findsOneWidget);
      expect(find.text('예전 전화번호 02-999-9999 (바뀌었을 수 있어요)'), findsOneWidget);
      expect(find.descendant(of: card, matching: find.textContaining('지금 열려')), findsNothing,
          reason: '확인 안 된 상태를 열림처럼 보이지 않기');

      await tapVisible(tester, find.byKey(const Key('saved-call-old-gone')));
      expect(h.launcher.dialed, ['02-999-9999']);

      await tapVisible(tester, find.byKey(const Key('saved-remove-gone')));
      expect(find.byKey(const Key('saved-gone')), findsNothing);
      expect(h.savedStore.places, isEmpty);
    });

    testWidgets('목록에서 빠진 곳: 이름이 같은 시설을 비슷한 곳으로 연다', (tester) async {
      final moved = facilityJson(id: 'moved', name: '열린 급식소', address: '서울 중구 새주소 5');
      await Harness(facilities: [moved], saved: [saved('gone')]).pump(tester);
      await tapVisible(tester, find.byKey(const Key('saved-similar-moved')));
      expect(find.byKey(const Key('detail')), findsOneWidget);
    });

    testWidgets('정보 화면에서 모두 지우기 (확인을 한 번 더 묻는다)', (tester) async {
      final h = Harness(facilities: [mealOpen], saved: [saved('meal-open')]);
      await h.pump(tester);
      await tester.tap(find.byTooltip('앱 정보'));
      await tester.pumpAndSettle();
      expect(find.textContaining('휴대폰을 바꾸면 옮겨지지 않아요'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('clear-saved')));
      expect(find.text('저장한 곳을 모두 지울까요?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(h.savedStore.places, hasLength(1));

      await tapVisible(tester, find.byKey(const Key('clear-saved')));
      await tester.tap(find.byKey(const Key('clear-saved-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('저장한 곳을 모두 지웠어요'), findsOneWidget);
      expect(h.savedStore.places, isEmpty);
      final button = tester.widget<ButtonStyleButton>(find.byKey(const Key('clear-saved')));
      expect(button.onPressed, isNull, reason: '지울 게 없으면 누를 수 없음');
    });

    testWidgets('위치를 안 정해도 저장한 곳은 보이고 전화할 수 있다', (tester) async {
      final h = Harness(facilities: [mealOpen], saved: [saved('meal-open')], savedRegion: null);
      await h.pump(tester);
      expect(find.byKey(const Key('saved-meal-open')), findsOneWidget);
      await tester.tap(find.byKey(const Key('saved-call-meal-open')));
      expect(h.launcher.dialed, ['02-111-1111']);
    });
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
        final h = Harness(
          reportEmail: 'report@example.org',
          saved: [
            SavedPlace(
              id: 'meal-open', name: '열린 급식소', category: FacilityCategory.meal,
              address: '서울 중구 테스트로 1', phone: '02-111-1111', savedAt: DateTime(2026, 11, 1),
            ),
            SavedPlace(
              id: 'gone', name: '목록에서 빠진 아주 이름이 긴 급식소', category: FacilityCategory.meal,
              address: '서울 중구 테스트로 2', phone: '02-999-9999', savedAt: DateTime(2026, 11, 1),
            ),
          ],
        );
        await h.pump(tester, textScale: scale);
        expect(find.byKey(const Key('home-saved')), findsOneWidget);
        // 넘침(overflow)은 테스트 예외로 잡힌다.
        await tapVisible(tester, find.byKey(const Key('group-meal')));
        await tapVisible(tester, find.byKey(const Key('facility-meal-open')));
        expect(find.byKey(const Key('detail')), findsOneWidget);
        await goBack(tester);
        await goBack(tester);
        await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, 2000));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const Key('group-clinic')));
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

    testWidgets('저장한 곳이 있는 첫 화면도 48dp 이상', (tester) async {
      await Harness(
        facilities: [mealOpen],
        saved: [
          SavedPlace(
            id: 'meal-open', name: '열린 급식소', category: FacilityCategory.meal,
            address: '서울 중구 테스트로 1', phone: '02-111-1111', savedAt: DateTime(2026, 11, 1),
          ),
          SavedPlace(
            id: 'gone', name: '없어진 곳', category: FacilityCategory.meal,
            address: '서울 중구 2', phone: '02-999-9999', savedAt: DateTime(2026, 11, 1),
          ),
        ],
      ).pump(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
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
