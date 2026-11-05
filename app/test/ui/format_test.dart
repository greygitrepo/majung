import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:majung/domain/geo.dart';
import 'package:majung/domain/opening_hours.dart';
import 'package:majung/l10n/app_localizations.dart';
import 'package:majung/services/launcher.dart';
import 'package:majung/ui/format.dart';

void main() {
  final l = lookupL10n(const Locale('ko'));
  final now = DateTime(2026, 11, 2, 12); // 월요일

  test('koreanTime', () {
    expect(koreanTime(l, 0, 0), '밤 12시');
    expect(koreanTime(l, 9, 0), '오전 9시');
    expect(koreanTime(l, 11, 30), '오전 11시 30분');
    expect(koreanTime(l, 12, 0), '낮 12시');
    expect(koreanTime(l, 12, 30), '낮 12시 30분');
    expect(koreanTime(l, 13, 5), '오후 1시 5분');
    expect(koreanTime(l, 23, 59), '오후 11시 59분');
  });

  test('relativeTime: 오늘·내일·요일', () {
    expect(relativeTime(l, DateTime(2026, 11, 2, 17), now), '오늘 오후 5시');
    expect(relativeTime(l, DateTime(2026, 11, 3, 9), now), '내일 오전 9시');
    expect(relativeTime(l, DateTime(2026, 11, 6, 11, 30), now), '금요일 오전 11시 30분');
  });

  test('statusText', () {
    expect(statusText(l, OpenStatus(OpenState.open, closesAt: DateTime(2026, 11, 2, 13)), now).detail, '오후 1시까지');
    expect(statusText(l, OpenStatus(OpenState.open, closesAt: DateTime(2026, 11, 3, 9)), now).detail,
        '내일 오전 9시까지');
    expect(statusText(l, OpenStatus(OpenState.open, closesAt: DateTime(2026, 11, 3)), now).detail, '밤 12시까지');
    expect(statusText(l, OpenStatus(OpenState.closed, nextOpen: DateTime(2026, 11, 3, 11, 30)), now).detail,
        '내일 오전 11시 30분에 열어요');
    expect(statusText(l, const OpenStatus(OpenState.closed), now).detail, '다음 운영일은 전화로 확인하세요');
    expect(statusText(l, const OpenStatus(OpenState.unknown), now).headline, '운영 시간 확인 필요');
  });

  test('hoursRuleText', () {
    HoursRule r(String o, String c) => HoursRule.fromJson({'days': ['mon'], 'open': o, 'close': c});
    expect(hoursRuleText(l, r('11:30', '13:00')), '오전 11시 30분 ~ 오후 1시');
    expect(hoursRuleText(l, r('18:00', '09:00')), '오후 6시 ~ 내일 오전 9시');
    expect(hoursRuleText(l, r('18:00', '24:00')), '오후 6시 ~ 밤 12시');
    expect(hoursRuleText(l, r('00:00', '24:00')), '24시간');
  });

  group('groupHoursByDay', () {
    HoursRule r(List<String> days, String o, String c) => HoursRule.fromJson({'days': days, 'open': o, 'close': c});
    const all = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

    test('매일 같으면 한 줄', () {
      final g = groupHoursByDay(l, [r(all, '08:00', '10:00'), r(all, '17:00', '19:00')]);
      expect(g.map((x) => x.label), ['매일']);
      expect(g.single.text, '오전 8시 ~ 오전 10시\n오후 5시 ~ 오후 7시');
    });
    test('평일·주말', () {
      final g = groupHoursByDay(l, [r(['mon', 'tue', 'wed', 'thu', 'fri'], '11:30', '13:00')]);
      expect(g.map((x) => x.label), ['월~금', '토·일']);
      expect(g.last.text, '쉬어요');
    });
    test('띄엄띄엄', () {
      final g = groupHoursByDay(l, [r(['mon', 'tue', 'wed', 'fri', 'sat'], '11:00', '13:00')]);
      expect(g.map((x) => x.label), ['월~수', '목', '금·토', '일']);
    });
  });

  test('walkText', () {
    expect(walkText(l, 350), '걸어서 약 7분 (350m)');
  });

  test('길찾기 링크: 네이버 → 카카오 → geo → 웹, 출발지 없음', () {
    final uris = directionUris('명동 급식소', const GeoPoint(37.5, 126.9), appId: 'kr.or.majung.app');
    expect(uris.map((u) => u.scheme), ['nmap', 'kakaomap', 'geo', 'https']);
    expect(uris.first.queryParameters['dname'], '명동 급식소');
    expect(uris.first.queryParameters.containsKey('slat'), isFalse);
    expect(uris.first.queryParameters['appname'], 'kr.or.majung.app');
  });
}
