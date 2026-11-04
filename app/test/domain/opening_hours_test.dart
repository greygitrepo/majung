import 'package:flutter_test/flutter_test.dart';
import 'package:majung/domain/opening_hours.dart';

// 2026-11-02 = 월요일
DateTime mon(int h, [int m = 0]) => DateTime(2026, 11, 2, h, m);
DateTime day(int dayOfMonth, int h, [int m = 0]) => DateTime(2026, 11, dayOfMonth, h, m);

OpeningHours hours(List<Map<String, dynamic>> rules, {HolidayPolicy? holiday}) =>
    OpeningHours(rules.map(HoursRule.fromJson).toList(), holidayPolicy: holiday);

void main() {
  test('기준 날짜 확인: 2026-11-02는 월요일', () {
    expect(mon(0).weekday, DateTime.monday);
  });

  group('parseClock', () {
    test('정상 값', () {
      expect(parseClock('00:00'), 0);
      expect(parseClock('9:05'), 545);
      expect(parseClock('24:00'), 1440);
    });
    test('잘못된 값은 FormatException', () {
      for (final bad in ['25:00', '12:60', '24:30', 'noon', '', '12']) {
        expect(() => parseClock(bad), throwsFormatException, reason: bad);
      }
    });
  });

  group('HoursRule.fromJson', () {
    test('알 수 없는 요일은 거부', () {
      expect(() => HoursRule.fromJson({'days': ['monday'], 'open': '09:00', 'close': '10:00'}),
          throwsFormatException);
    });
    test('빈 요일은 거부', () {
      expect(() => HoursRule.fromJson({'days': [], 'open': '09:00', 'close': '10:00'}),
          throwsFormatException);
    });
    test('00:00~24:00 과 00:00~00:00 은 24시간', () {
      expect(HoursRule.fromJson({'days': ['mon'], 'open': '00:00', 'close': '24:00'}).isAllDay, isTrue);
      expect(HoursRule.fromJson({'days': ['mon'], 'open': '00:00', 'close': '00:00'}).isAllDay, isTrue);
    });
  });

  group('점심 급식 (월~금 11:30~13:00)', () {
    final lunch = hours([
      {'days': ['mon', 'tue', 'wed', 'thu', 'fri'], 'open': '11:30', 'close': '13:00'},
    ]);

    test('여는 시각 정각에는 열림', () {
      final s = lunch.statusAt(mon(11, 30));
      expect(s.state, OpenState.open);
      expect(s.closesAt, mon(13));
    });
    test('닫기 30분 전부터 곧 닫힘', () {
      expect(lunch.statusAt(mon(12, 29)).state, OpenState.open);
      expect(lunch.statusAt(mon(12, 30)).state, OpenState.closingSoon);
    });
    test('닫는 시각 정각에는 닫힘, 다음 날 11:30에 열림', () {
      final s = lunch.statusAt(mon(13));
      expect(s.state, OpenState.closed);
      expect(s.nextOpen, day(3, 11, 30));
    });
    test('여는 시각 전이면 오늘 연다', () {
      expect(lunch.statusAt(mon(8)).nextOpen, mon(11, 30));
    });
    test('금요일 오후 → 다음 주 월요일', () {
      expect(lunch.statusAt(day(6, 15)).nextOpen, day(9, 11, 30));
    });
    test('토요일은 닫힘', () {
      expect(lunch.statusAt(day(7, 12)).state, OpenState.closed);
    });
  });

  group('자정을 넘기는 쉼터 (매일 18:00~09:00)', () {
    final shelter = hours([
      {'days': ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'], 'open': '18:00', 'close': '09:00'},
    ]);

    test('저녁에 열림, 다음 날 09:00에 닫음', () {
      final s = shelter.statusAt(mon(22));
      expect(s.state, OpenState.open);
      expect(s.closesAt, day(3, 9));
    });
    test('새벽에도 열림 (전날 시작 구간)', () {
      final s = shelter.statusAt(day(3, 3));
      expect(s.state, OpenState.open);
      expect(s.closesAt, day(3, 9));
    });
    test('낮에는 닫힘, 오늘 18:00에 엶', () {
      final s = shelter.statusAt(mon(12));
      expect(s.state, OpenState.closed);
      expect(s.nextOpen, mon(18));
    });
  });

  test('월요일만 밤샘 운영이면 화요일 새벽은 열리고 수요일 새벽은 닫힘', () {
    final h = hours([
      {'days': ['mon'], 'open': '20:00', 'close': '06:00'},
    ]);
    expect(h.statusAt(day(3, 2)).state, OpenState.open);
    expect(h.statusAt(day(4, 2)).state, OpenState.closed);
  });

  test('24시간 운영은 항상 열림', () {
    final h = hours([
      {'days': ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'], 'open': '00:00', 'close': '24:00'},
    ]);
    expect(h.statusAt(mon(3)).isOpenNow, isTrue);
    expect(h.statusAt(mon(23, 59)).isOpenNow, isTrue);
  });

  test('하루에 두 번 (점심·저녁)', () {
    final h = hours([
      {'days': ['mon'], 'open': '11:00', 'close': '13:00'},
      {'days': ['mon'], 'open': '17:00', 'close': '19:00'},
    ]);
    expect(h.statusAt(mon(14)).nextOpen, mon(17));
    expect(h.statusAt(mon(18)).closesAt, mon(19));
  });

  test('운영 시간 정보가 없으면 모름', () {
    expect(const OpeningHours([]).statusAt(mon(12)).state, OpenState.unknown);
  });

  test('7일 안에 여는 날이 없으면 nextOpen 은 null', () {
    final h = hours([
      {'days': ['mon'], 'open': '09:00', 'close': '10:00'},
    ], holiday: HolidayPolicy.closed);
    // 모든 날이 공휴일이라고 가정
    expect(h.statusAt(mon(12), isHoliday: (_) => true).nextOpen, isNull);
  });

  group('공휴일', () {
    final rule = [
      {'days': ['mon', 'tue', 'wed', 'thu', 'fri'], 'open': '11:00', 'close': '13:00'},
    ];
    bool isMonHoliday(DateTime d) => d == DateTime(2026, 11, 2);

    test('공휴일 운영 정보가 없으면 판정은 하되 확인 필요 표시', () {
      final s = hours(rule).statusAt(mon(12), isHoliday: isMonHoliday);
      expect(s.state, OpenState.open);
      expect(s.holidayUncertain, isTrue);
    });
    test('공휴일 휴무면 닫힘, 다음 평일에 엶', () {
      final s = hours(rule, holiday: HolidayPolicy.closed).statusAt(mon(12), isHoliday: isMonHoliday);
      expect(s.state, OpenState.closed);
      expect(s.holidayUncertain, isFalse);
      expect(s.nextOpen, day(3, 11));
    });
    test('공휴일 운영이면 평소대로', () {
      final s = hours(rule, holiday: HolidayPolicy.open).statusAt(mon(12), isHoliday: isMonHoliday);
      expect(s.state, OpenState.open);
      expect(s.holidayUncertain, isFalse);
    });
    test('공휴일이 아닌 날에는 경고 없음', () {
      expect(hours(rule).statusAt(day(3, 12), isHoliday: isMonHoliday).holidayUncertain, isFalse);
    });
  });
}
