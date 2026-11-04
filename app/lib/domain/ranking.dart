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

/// 이 거리 안의 시설을 "가까운 곳"으로 본다.
const nearbyRadiusMeters = 20000.0;

/// 가까운 곳이 이보다 적으면(시골 등) 거리와 상관없이 가까운 순으로 이만큼 채운다.
const minNearbyCount = 5;

/// 전국 데이터에서 가까운 곳만 골라 정렬한다.
///
/// - 기준 위치가 없으면 빈 목록 (전국을 이름순으로 늘어놓으면 쓸모가 없다 → 화면이 위치를 먼저 묻는다).
/// - 반경 [nearbyRadiusMeters] 안, 그 안에 [minNearbyCount] 곳이 안 되면 가까운 순으로 채운다.
///   이용 대상(누구나 / 어르신 경로식당)별로 따로 센다.
/// - 정렬: 누구나 → 어르신 경로식당. 각 묶음 안에서 (사람이 확인한) 지금 열린 곳 → 나머지 →
///   180일 넘은 정보. 진료는 무료 진료소를 보건소보다 먼저. 그다음 가까운 순.
List<RankedFacility> rankFacilities(
  Dataset dataset, {
  required CategoryGroup group,
  required DateTime now,
  GeoPoint? origin,
}) {
  if (origin == null) return const [];

  final byAudience = <Audience, List<RankedFacility>>{};
  for (final f in dataset.facilities) {
    if (!group.contains(f.category)) continue;
    byAudience.putIfAbsent(f.audience, () => []).add(RankedFacility(
          facility: f,
          status: f.statusAt(now, isHoliday: dataset.isHoliday),
          freshness: f.freshnessAt(now),
          distance: distanceMeters(origin, f.location),
        ));
  }

  int bucket(RankedFacility r) {
    if (r.freshness == Freshness.expired) return 2;
    return r.status.isOpenNow ? 0 : 1;
  }

  int clinicRank(RankedFacility r) => switch (r.facility.clinicType) {
        ClinicType.freeClinic => 0,
        ClinicType.hospitalSupport => 1,
        ClinicType.healthCenter => 2,
        null => 1,
      };

  int compare(RankedFacility a, RankedFacility b) {
    final byBucket = bucket(a).compareTo(bucket(b));
    if (byBucket != 0) return byBucket;
    final byClinic = clinicRank(a).compareTo(clinicRank(b));
    if (byClinic != 0) return byClinic;
    final byDistance = a.distance!.compareTo(b.distance!);
    if (byDistance != 0) return byDistance;
    return a.facility.name.compareTo(b.facility.name);
  }

  List<RankedFacility> nearby(List<RankedFacility> all) {
    all.sort((a, b) => a.distance!.compareTo(b.distance!));
    final within = all.where((r) => r.distance! <= nearbyRadiusMeters).toList();
    final picked = within.length >= minNearbyCount ? within : all.take(minNearbyCount).toList();
    return picked..sort(compare);
  }

  return [
    for (final audience in Audience.values) ...nearby(byAudience[audience] ?? []),
  ];
}
