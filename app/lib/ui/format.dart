import 'package:flutter/material.dart';

import '../domain/category.dart';
import '../domain/freshness.dart';
import '../domain/geo.dart';
import '../domain/opening_hours.dart';
import '../l10n/app_localizations.dart';

/// "오전 11시 30분", "오후 1시", "밤 12시". 읽어 주기(TalkBack)에도 자연스럽다.
String koreanTime(L10n l, int hour, int minute) {
  if (hour == 0 && minute == 0) return l.midnight;
  final period = hour < 12 ? l.am : (hour == 12 ? l.noon : l.pm);
  var h = hour % 12;
  if (h == 0) h = 12;
  return minute == 0 ? l.hourOnly(period, h) : l.hourMinute(period, h, minute);
}

String weekdayShort(L10n l, Weekday d) => switch (d) {
      Weekday.mon => l.weekdayMon,
      Weekday.tue => l.weekdayTue,
      Weekday.wed => l.weekdayWed,
      Weekday.thu => l.weekdayThu,
      Weekday.fri => l.weekdayFri,
      Weekday.sat => l.weekdaySat,
      Weekday.sun => l.weekdaySun,
    };

/// 오늘/내일/요일 + 시각: "내일 오전 9시", "금요일 오전 11시 30분".
String relativeTime(L10n l, DateTime t, DateTime now) {
  final days = daysBetween(now, t);
  final time = koreanTime(l, t.hour, t.minute);
  if (days <= 0) return '${l.today} $time';
  if (days == 1) return '${l.tomorrow} $time';
  return '${l.weekdayFull(weekdayShort(l, Weekday.fromNumber(t.weekday)))} $time';
}

/// 닫는 시각은 오늘이면 "오후 1시", 아니면 "내일 오전 9시".
String closingTime(L10n l, DateTime t, DateTime now) {
  // 24:00 은 다음 날 0시로 표현되므로 "밤 12시"로 보여준다.
  if (t.hour == 0 && t.minute == 0 && daysBetween(now, t) == 1) return l.midnight;
  return daysBetween(now, t) <= 0 ? koreanTime(l, t.hour, t.minute) : relativeTime(l, t, now);
}

class StatusText {
  const StatusText(this.headline, this.detail, this.tone);
  final String headline;
  final String detail;
  final StatusTone tone;
}

enum StatusTone { open, closingSoon, closed, unknown }

StatusText statusText(L10n l, OpenStatus s, DateTime now) => switch (s.state) {
      OpenState.open => StatusText(
          l.statusOpen, s.closesAt == null ? '' : l.statusUntil(closingTime(l, s.closesAt!, now)), StatusTone.open),
      OpenState.closingSoon => StatusText(
          l.statusClosingSoon, l.statusUntil(closingTime(l, s.closesAt!, now)), StatusTone.closingSoon),
      OpenState.closed => StatusText(
          l.statusClosed,
          s.nextOpen == null ? l.statusNoNextOpen : l.statusOpensAt(relativeTime(l, s.nextOpen!, now)),
          StatusTone.closed),
      OpenState.unknown => StatusText(l.statusUnknown, l.statusCallFirst, StatusTone.unknown),
    };

String walkText(L10n l, double meters) => l.walk(walkingMinutes(meters), formatDistance(meters));

String hoursRuleText(L10n l, HoursRule r) {
  if (r.isAllDay) return l.allDay;
  final open = koreanTime(l, r.open ~/ 60, r.open % 60);
  final closeMin = r.close == 1440 ? 0 : r.close;
  final close = koreanTime(l, closeMin ~/ 60, closeMin % 60);
  return '$open ~ ${r.crossesMidnight && r.close != 0 ? '${l.tomorrow} ' : ''}$close';
}

String groupTitle(L10n l, CategoryGroup g) => switch (g) {
      CategoryGroup.meal => l.groupMeal,
      CategoryGroup.sleep => l.groupSleep,
      CategoryGroup.wash => l.groupWash,
      CategoryGroup.clinic => l.groupClinic,
      CategoryGroup.groceries => l.groupGroceries,
    };

String groupSubtitle(L10n l, CategoryGroup g) => switch (g) {
      CategoryGroup.meal => l.groupMealSub,
      CategoryGroup.sleep => l.groupSleepSub,
      CategoryGroup.wash => l.groupWashSub,
      CategoryGroup.clinic => l.groupClinicSub,
      CategoryGroup.groceries => l.groupGroceriesSub,
    };

IconData groupIcon(CategoryGroup g) => switch (g) {
      CategoryGroup.meal => Icons.rice_bowl_rounded,
      CategoryGroup.sleep => Icons.bed_rounded,
      CategoryGroup.wash => Icons.shower,
      CategoryGroup.clinic => Icons.local_hospital,
      CategoryGroup.groceries => Icons.shopping_basket,
    };

String landmarkName(L10n l, Landmark m) => switch (m.id) {
      'seoul_station' => l.landmarkSeoulStation,
      'euljiro' => l.landmarkEuljiro,
      'yeongdeungpo' => l.landmarkYeongdeungpo,
      'yongsan' => l.landmarkYongsan,
      _ => m.id,
    };

String dateText(DateTime d) =>
    '${d.year}년 ${d.month}월 ${d.day}일';

/// 같은 운영시간인 요일을 묶는다: 매일 / 월~금 / 토·일.
class DayGroup {
  const DayGroup(this.days, this.label, this.text);
  final List<Weekday> days;
  final String label;
  final String text;
}

List<DayGroup> groupHoursByDay(L10n l, List<HoursRule> rules) {
  String textFor(Weekday d) {
    final dayRules = rules.where((r) => r.days.contains(d)).toList()..sort((a, b) => a.open.compareTo(b.open));
    return dayRules.isEmpty ? l.closedDay : dayRules.map((r) => hoursRuleText(l, r)).join('\n');
  }

  // 같은 글이 이어지는 요일끼리 묶는다(월요일부터 순서대로).
  final runs = <List<Weekday>>[];
  for (final d in Weekday.values) {
    if (runs.isNotEmpty && textFor(runs.last.last) == textFor(d)) {
      runs.last.add(d);
    } else {
      runs.add([d]);
    }
  }
  String label(List<Weekday> days) {
    if (days.length == 7) return l.everyDay;
    if (days.length >= 3) return '${weekdayShort(l, days.first)}~${weekdayShort(l, days.last)}';
    return days.map((d) => weekdayShort(l, d)).join('·');
  }

  return [for (final run in runs) DayGroup(run, label(run), textFor(run.first))];
}
