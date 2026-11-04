import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/geo.dart';
import '../../domain/ranking.dart';
import '../../l10n/app_localizations.dart';
import '../format.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets.dart';

/// 목록과 같은 데이터를 지도에 핀으로. 핀을 누르면 아래에 요약 카드.
class MapView extends StatefulWidget {
  const MapView({super.key, required this.items, required this.now, required this.onOpen});

  final List<RankedFacility> items;
  final DateTime now;
  final void Function(RankedFacility) onOpen;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  RankedFacility? _selected;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scope = AppScope.of(context);
    final origin = scope.controller.origin.point;
    final center = origin ?? (widget.items.isNotEmpty ? widget.items.first.facility.location : Landmark.seoulStation.point);
    final tileUrl = scope.config.tileUrlTemplate;
    final colors = context.statusColors;

    return Stack(
      children: [
        FlutterMap(
          key: const Key('map'),
          options: MapOptions(
            initialCenter: LatLng(center.lat, center.lng),
            initialZoom: 15,
            minZoom: 10,
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
        if (_selected == null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
              ),
              child: Text(l.mapHint, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            ),
          ),
        if (_selected != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: FacilityCard(
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
          ),
      ],
    );
  }
}
