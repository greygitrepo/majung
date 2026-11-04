/// 운영 시간 표현과 "지금 열림" 판정.
///
/// 현재 시각은 항상 인자로 받는다(테스트 가능하게, DateTime.now() 직접 호출 금지).
library;

/// DateTime.weekday 와 같은 값: 월=1 ... 일=7.
enum Weekday {
  mon(1),
  tue(2),
  wed(3),
  thu(4),
  fri(5),
  sat(6),
  sun(7);

  const Weekday(this.number);
  final int number;

  static Weekday fromNumber(int n) => values.firstWhere((d) => d.number == n);

  static Weekday? tryParse(String value) {
    for (final d in values) {
      if (d.name == value) return d;
    }
    return null;
  }

  Weekday get previous => fromNumber(number == 1 ? 7 : number - 1);
}

/// "HH:MM" → 자정부터의 분. "24:00" 허용(=1440).
int parseClock(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) throw FormatException('시간 형식 오류: $value');
  final h = int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  if (h > 24 || m > 59 || (h == 24 && m != 0)) {
    throw FormatException('시간 범위 오류: $value');
  }
  return h * 60 + m;
}

String formatClock(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// 특정 요일들에 open~close 운영. close <= open 이면 자정을 넘긴다(예: 18:00~09:00).
class HoursRule {
  HoursRule({required this.days, required this.open, required this.close}) {
    if (days.isEmpty) throw const FormatException('요일이 비어 있음');
    if (open == close && !(open == 0 && close == 0)) {
      throw FormatException('여는 시간과 닫는 시간이 같음: ${formatClock(open)}');
    }
  }

  factory HoursRule.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    if (rawDays is! List) throw const FormatException('days 누락');
    final days = <Weekday>{};
    for (final d in rawDays) {
      final day = Weekday.tryParse('$d');
      if (day == null) throw FormatException('알 수 없는 요일: $d');
      days.add(day);
    }
    final open = parseClock('${json['open']}');
    var close = parseClock('${json['close']}');
    // "00:00"~"24:00" 또는 "00:00"~"00:00" 은 24시간 운영.
    if (open == 0 && (close == 0 || close == 1440)) close = 1440;
    return HoursRule(days: days, open: open, close: close);
  }

  final Set<Weekday> days;
  final int open;
  final int close;

  bool get crossesMidnight => close <= open;
  bool get isAllDay => open == 0 && close == 1440;
}

enum OpenState { open, closingSoon, closed, unknown }

class OpenStatus {
  const OpenStatus(
    this.state, {
    this.closesAt,
    this.nextOpen,
    this.holidayUncertain = false,
  });

  final OpenState state;

  /// 열려 있을 때 닫는 시각.
  final DateTime? closesAt;

  /// 닫혀 있을 때 다음에 여는 시각(7일 안에 없으면 null).
  final DateTime? nextOpen;

  /// 오늘이 공휴일인데 공휴일 운영 정보가 없음 → "공휴일 운영 확인 필요".
  final bool holidayUncertain;

  bool get isOpenNow =>
      state == OpenState.open || state == OpenState.closingSoon;
}

/// 공휴일 운영 방침. null(모름)이면 공휴일에 경고를 띄운다.
enum HolidayPolicy { open, closed }

class OpeningHours {
  const OpeningHours(this.rules, {this.holidayPolicy});

  final List<HoursRule> rules;
  final HolidayPolicy? holidayPolicy;

  static const closingSoonMinutes = 30;

  bool get isEmpty => rules.isEmpty;

  /// [now] 기준 운영 상태. [isHoliday]는 날짜를 받아 공휴일인지 알려준다.
  OpenStatus statusAt(DateTime now, {bool Function(DateTime date)? isHoliday}) {
    if (rules.isEmpty) return const OpenStatus(OpenState.unknown);
    final holiday = isHoliday ?? (_) => false;
    final todayIsHoliday = holiday(_dateOnly(now));

    if (todayIsHoliday && holidayPolicy == HolidayPolicy.closed) {
      return OpenStatus(
        OpenState.closed,
        nextOpen: _nextOpening(now, holiday),
      );
    }
    final uncertain = todayIsHoliday && holidayPolicy == null;

    final closesAt = _currentClosing(now, holiday);
    if (closesAt != null) {
      final left = closesAt.difference(now).inMinutes;
      return OpenStatus(
        left <= closingSoonMinutes ? OpenState.closingSoon : OpenState.open,
        closesAt: closesAt,
        holidayUncertain: uncertain,
      );
    }
    return OpenStatus(
      OpenState.closed,
      nextOpen: _nextOpening(now, holiday),
      holidayUncertain: uncertain,
    );
  }

  /// 지금 열려 있으면 닫는 시각, 아니면 null.
  DateTime? _currentClosing(DateTime now, bool Function(DateTime) holiday) {
    final today = _dateOnly(now);
    final minute = now.hour * 60 + now.minute;
    final weekday = Weekday.fromNumber(now.weekday);
    DateTime? best;

    void consider(DateTime candidate) {
      if (best == null || candidate.isAfter(best!)) best = candidate;
    }

    for (final r in rules) {
      // 오늘 시작한 구간
      if (r.days.contains(weekday) && !_skipDay(today, holiday)) {
        if (r.crossesMidnight) {
          if (minute >= r.open) {
            consider(_at(today.add(const Duration(days: 1)), r.close));
          }
        } else if (minute >= r.open && minute < r.close) {
          consider(_at(today, r.close));
        }
      }
      // 어제 시작해 자정을 넘긴 구간
      final yesterday = today.subtract(const Duration(days: 1));
      if (r.crossesMidnight &&
          r.days.contains(weekday.previous) &&
          !_skipDay(yesterday, holiday) &&
          minute < r.close) {
        consider(_at(today, r.close));
      }
    }
    return best;
  }

  DateTime? _nextOpening(DateTime now, bool Function(DateTime) holiday) {
    final today = _dateOnly(now);
    final minute = now.hour * 60 + now.minute;
    for (var offset = 0; offset <= 7; offset++) {
      final day = today.add(Duration(days: offset));
      if (_skipDay(day, holiday)) continue;
      final weekday = Weekday.fromNumber(day.weekday);
      final opens = rules
          .where((r) => r.days.contains(weekday))
          .map((r) => r.open)
          .where((open) => offset > 0 || open > minute)
          .toList()
        ..sort();
      if (opens.isNotEmpty) return _at(day, opens.first);
    }
    return null;
  }

  bool _skipDay(DateTime day, bool Function(DateTime) holiday) =>
      holidayPolicy == HolidayPolicy.closed && holiday(day);
}

DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime _at(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day).add(Duration(minutes: minutes));
