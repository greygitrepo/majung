/// 정보 신선도 (docs/policy/data.md §3).
enum Freshness {
  /// 90일 이내 확인.
  fresh,

  /// 90일 초과 — "오래됐을 수 있어요" 경고.
  stale,

  /// 180일 초과 — 목록 맨 아래로.
  expired,
}

const staleAfterDays = 90;
const expiredAfterDays = 180;

/// 달력 날짜 기준 경과 일수(시각·서머타임 영향 없음).
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

Freshness freshnessOf(DateTime lastVerified, DateTime now) {
  final days = daysBetween(lastVerified, now);
  if (days > expiredAfterDays) return Freshness.expired;
  if (days > staleAfterDays) return Freshness.stale;
  return Freshness.fresh;
}
