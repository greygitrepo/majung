import 'package:flutter_test/flutter_test.dart';
import 'package:majung/domain/facility.dart';
import 'package:majung/domain/freshness.dart';
import 'package:majung/domain/geo.dart';
import 'package:majung/domain/opening_hours.dart';
import 'package:majung/domain/ranking.dart';
import 'package:majung/ui/screens/map_screen.dart';

import '../fixtures.dart';

RankedFacility ranked(String id, double lat, double lng, double? distance, {OpenState state = OpenState.unknown}) =>
    RankedFacility(
      facility: Facility.fromJson(facilityJson(id: id, lat: lat, lng: lng)),
      status: OpenStatus(state),
      freshness: Freshness.fresh,
      distance: distance,
    );

void main() {
  const origin = GeoPoint(37.5640, 126.9975);

  test('기준 위치와 가장 가까운 3곳 (목록 순서가 아니라 거리 순)', () {
    final items = [
      ranked('far-open', 37.60, 127.10, 9000, state: OpenState.open), // 목록 맨 앞(열림)이지만 멀다
      ranked('a', 37.555, 126.972, 2000),
      ranked('b', 37.566, 127.016, 1700),
      ranked('c', 37.570, 127.000, 700),
    ];
    final pts = mapFitPoints(origin, items);
    expect(pts.first, origin);
    expect(pts.skip(1).toList(), [
      items[3].facility.location,
      items[2].facility.location,
      items[1].facility.location,
    ]);
  });

  test('시설이 적으면 있는 만큼, 없으면 기준 위치만', () {
    expect(mapFitPoints(origin, [ranked('a', 37.555, 126.972, 2000)]).length, 2);
    expect(mapFitPoints(origin, []), [origin]);
  });

  test('기준 위치가 없으면 목록 앞쪽 3곳', () {
    final items = [for (var i = 0; i < 5; i++) ranked('f$i', 37.5 + i / 100, 127.0, null)];
    expect(mapFitPoints(null, items), [for (final r in items.take(3)) r.facility.location]);
  });
}
