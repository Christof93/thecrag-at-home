import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/ascent.dart';
import 'day_tooltip.dart';

/// World map with one dot per climbing day.
///
/// Days at the same spot (e.g. the same crag) would sit exactly on top of
/// each other, so they are drawn as one dot whose tooltip lists every day.
/// Dot size grows with the number of ascents.
class AscentMap extends StatelessWidget {
  const AscentMap({super.key, required this.days});

  final List<ClimbingDay> days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Group days by location rounded to ~100 m.
    final spots = <String, List<ClimbingDay>>{};
    final spotPos = <String, LatLng>{};
    for (final d in days) {
      final p = d.position;
      if (p == null) continue;
      final key = '${p.$1.toStringAsFixed(3)},${p.$2.toStringAsFixed(3)}';
      spots.putIfAbsent(key, () => []).add(d);
      spotPos[key] = LatLng(p.$1, p.$2);
    }

    final markers = <Marker>[];
    final entries = spots.entries.toList()
      // Draw small spots last so they stay hoverable on top of big ones.
      ..sort((a, b) => _total(b.value).compareTo(_total(a.value)));
    for (final e in entries) {
      final total = _total(e.value);
      final size = 10 + 3 * math.sqrt(total.toDouble());
      markers.add(
        Marker(
          point: spotPos[e.key]!,
          width: size,
          height: size,
          child: Tooltip(
            message: describeDays(e.value),
            waitDuration: Duration.zero,
            triggerMode: TooltipTriggerMode.tap,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.65),
                  border: Border.all(color: scheme.onPrimary, width: 1.2),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final points = spotPos.values.toList();
    final MapOptions options;
    if (points.length >= 2) {
      options = MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(40),
          maxZoom: 12,
        ),
        minZoom: 1.5,
      );
    } else {
      options = MapOptions(
        initialCenter: points.isEmpty ? const LatLng(30, 0) : points.first,
        initialZoom: points.isEmpty ? 2 : 10,
        minZoom: 1.5,
      );
    }

    return FlutterMap(
      // Rebuild the camera when the filtered set of spots changes.
      key: ValueKey(spots.keys.join('|')),
      options: options,
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'io.github.christof93.thecrag_at_home',
        ),
        MarkerLayer(markers: markers),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }

  static int _total(List<ClimbingDay> days) =>
      days.fold(0, (s, d) => s + d.count);
}
