import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app_controller.dart';
import '../../domain/geo.dart';
import '../../domain/ranking.dart';
import '../../l10n/app_localizations.dart';
import '../format.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets.dart';

/// 처음 지도를 열 때 화면에 들어와야 할 점: 기준 위치와 가장 가까운 [nearest]곳.
/// 고정 확대 수준으로 열면 가까운 곳이 화면 밖에 있어 "근처에 없음"처럼 보이기 때문.
/// 기준 위치가 없으면 목록 앞쪽 [nearest]곳.
List<GeoPoint> mapFitPoints(GeoPoint? origin, List<RankedFacility> items, {int nearest = 3}) {
  final sorted = [...items];
  if (origin != null) sorted.sort((a, b) => (a.distance ?? double.infinity).compareTo(b.distance ?? double.infinity));
  return [?origin, for (final r in sorted.take(nearest)) r.facility.location];
}

/// 목록과 같은 데이터를 지도에 핀으로. 핀을 누르면 아래에 요약 카드.
class MapView extends StatefulWidget {
  const MapView({super.key, required this.items, required this.now, required this.onOpen});

  final List<RankedFacility> items;
  final DateTime now;
  final void Function(RankedFacility) onOpen;

  @override
  State<MapView> createState() => _MapViewState();
}

/// 지도를 처음 열 때와 "내 위치로/처음 위치로" 버튼이 쓰는 화면 맞춤. 점이 1개 이하면 null.
CameraFit? _fitFor(List<GeoPoint> fit) => fit.length < 2
    ? null
    : CameraFit.coordinates(
        coordinates: [for (final p in fit) LatLng(p.lat, p.lng)],
        // 핀은 위로 52px, 아래에는 안내 카드와 버튼이 있어 위·아래 여백을 더 준다.
        padding: const EdgeInsets.fromLTRB(40, 72, 40, 180),
        maxZoom: 16,
        minZoom: 7,
      );

class _MapViewState extends State<MapView> {
  RankedFacility? _selected;
  final _map = MapController();
  bool _relocating = false;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  /// 지금 기준 위치와 가까운 곳이 보이게 지도를 옮긴다.
  void _recenter() {
    if (!mounted) return;
    final origin = AppScope.read(context).controller.origin.point;
    final pts = mapFitPoints(origin, widget.items);
    final fit = _fitFor(pts);
    if (fit != null) {
      _map.fitCamera(fit);
    } else if (pts.isNotEmpty) {
      _map.move(LatLng(pts.first.lat, pts.first.lng), 15);
    }
  }

  /// GPS 기준이면 위치를 한 번 새로 읽고(이동했을 수 있으므로), 지역 기준이면 그 기준점으로 되돌린다.
  /// 위치를 못 읽으면 전에 찾은 위치를 그대로 쓴다.
  Future<void> _onRecenter() async {
    final scope = AppScope.read(context);
    final c = scope.controller;
    final l = L10n.of(context);
    if (c.origin.kind == OriginKind.gps) {
      if (_relocating) return;
      setState(() => _relocating = true);
      final ok = await c.useGps();
      if (!mounted) return;
      setState(() {
        _relocating = false;
        _selected = null; // 거리가 바뀌었으니 예전 요약 카드는 닫는다
      });
      if (!ok) showSnack(context, l.mapLocateFailed);
      // 새 위치로 목록이 다시 그려진 뒤에 맞춘다.
      WidgetsBinding.instance.addPostFrameCallback((_) => _recenter());
    } else {
      _recenter();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scope = AppScope.of(context);
    final origin = scope.controller.origin.point;
    final center = origin ?? (widget.items.isNotEmpty ? widget.items.first.facility.location : const GeoPoint(36.5, 127.8)); // 기준 위치가 없을 때만: 국토 가운데
    final fit = mapFitPoints(origin, widget.items);
    final isGps = scope.controller.origin.kind == OriginKind.gps;
    final tileUrl = scope.config.tileUrlTemplate;
    final colors = context.statusColors;

    return Stack(
      children: [
        FlutterMap(
          key: const Key('map'),
          mapController: _map,
          options: MapOptions(
            initialCenter: LatLng(center.lat, center.lng),
            initialZoom: 14,
            // 점이 2개 이상이면 모두 보이게 맞춘다.
            initialCameraFit: _fitFor(fit),
            minZoom: 7,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onTap: (_, _) => setState(() => _selected = null),
          ),
          children: [
            if (tileUrl != null)
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: scope.config.appId,
                maxNativeZoom: 19,
              ),
            MarkerLayer(
              markers: [
                if (origin != null)
                  Marker(
                    point: LatLng(origin.lat, origin.lng),
                    width: 28,
                    height: 28,
                    child: Semantics(
                      label: l.originGps,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                for (final item in widget.items)
                  Marker(
                    point: LatLng(item.facility.location.lat, item.facility.location.lng),
                    width: 52,
                    height: 52,
                    alignment: Alignment.topCenter,
                    child: Semantics(
                      button: true,
                      label: '${item.facility.name}, ${statusText(l, item.status, widget.now).headline}',
                      child: GestureDetector(
                        key: Key('pin-${item.facility.id}'),
                        onTap: () => setState(() => _selected = item),
                        child: Icon(
                          Icons.location_on,
                          size: 52,
                          color: colors.forTone(statusText(l, item.status, widget.now).tone),
                          shadows: const [Shadow(blurRadius: 4, color: Colors.black45)],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // OSM(ODbL) 저작권 표시는 항상 보이게 한다.
            Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: Colors.white.withValues(alpha: 0.85),
                child: Text(l.mapAttribution, style: const TextStyle(fontSize: 13, color: Colors.black)),
              ),
            ),
          ],
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (origin != null)
                FilledButton.tonalIcon(
                  key: const Key('map-recenter'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    elevation: 3,
                  ),
                  onPressed: _relocating ? null : _onRecenter,
                  icon: _relocating
                      ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 3))
                      : Icon(isGps ? Icons.my_location : Icons.center_focus_strong),
                  label: Text(_relocating ? l.pickerLocating : (isGps ? l.mapRecenterGps : l.mapRecenterRegion)),
                ),
              const SizedBox(height: 10),
              if (_selected == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
                  ),
                  child: Text(l.mapHint, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                )
              else
                FacilityCard(
                  key: const Key('map-selected'),
                  item: _selected!,
                  now: widget.now,
                  onOpen: () => widget.onOpen(_selected!),
                  onCall: _selected!.facility.phone == null
                      ? null
                      : () async {
                          final ok = await scope.launcher.dial(_selected!.facility.phone!);
                          if (!ok && context.mounted) showSnack(context, l.launchFailed);
                        },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
