import 'category.dart';
import 'dataset.dart';
import 'facility.dart';
import 'freshness.dart';
import 'geo.dart';
import 'opening_hours.dart';

/// 목록 한 줄에 필요한 계산 결과.
class RankedFacility {
  const RankedFacility({
    required this.facility,
    required this.status,
    required this.freshness,
    this.distance,
  });

  final Facility facility;
  final OpenStatus status;
  final Freshness freshness;

  /// 기준 위치가 없으면 null.
  final double? distance;
}

/// 정렬 규칙: 지금 열린 곳 → 닫힌 곳 → 운영시간 모름 → 180일 넘은 정보.
/// 같은 묶음 안에서는 가까운 순(기준 위치 없으면 이름순).
List<RankedFacility> rankFacilities(
  Dataset dataset, {
  required CategoryGroup group,
  required DateTime now,
  GeoPoint? origin,
}) {
  final ranked = [
    for (final f in dataset.facilities)
      if (group.contains(f.category))
        RankedFacility(
          facility: f,
          status: f.hours.statusAt(now, isHoliday: dataset.isHoliday),
          freshness: f.freshnessAt(now),
          distance: origin == null ? null : distanceMeters(origin, f.location),
        ),
  ];

  int bucket(RankedFacility r) {
    if (r.freshness == Freshness.expired) return 3;
    return switch (r.status.state) {
      OpenState.open || OpenState.closingSoon => 0,
      OpenState.closed => 1,
      OpenState.unknown => 2,
    };
  }

  ranked.sort((a, b) {
    final byBucket = bucket(a).compareTo(bucket(b));
    if (byBucket != 0) return byBucket;
    if (a.distance != null && b.distance != null) {
      final byDistance = a.distance!.compareTo(b.distance!);
      if (byDistance != 0) return byDistance;
    }
    return a.facility.name.compareTo(b.facility.name);
  });
  return ranked;
}
