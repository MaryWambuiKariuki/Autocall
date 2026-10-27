import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/config.dart';
import '../core/theme.dart';

/// OpenStreetMap map (free, no API key). In dark mode the tiles are inverted so the map matches the theme.
class AutoMap extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final List<LatLng> route;
  final MapController? controller;
  final bool interactive;
  const AutoMap({super.key, required this.center, this.zoom = 14.5, this.markers = const [], this.route = const [],
      this.controller, this.interactive = true});

  static const _invert = ColorFilter.matrix(<double>[
    -0.9, 0, 0, 0, 255, 0, -0.9, 0, 0, 255, 0, 0, -0.9, 0, 255, 0, 0, 0, 1, 0]);

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center, initialZoom: zoom,
        interactionOptions: InteractionOptions(flags: interactive ? InteractiveFlag.all : InteractiveFlag.none),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: AppConfig.appPackage,
          tileBuilder: dark ? (c, tile, _) => ColorFiltered(colorFilter: _invert, child: tile) : null,
        ),
        if (route.length > 1)
          PolylineLayer(polylines: [Polyline(points: route, strokeWidth: 4.5, color: AppColors.orange)]),
        MarkerLayer(markers: markers),
        const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
      ],
    );
  }
}

Marker mePin(LatLng p, {String label = 'You'}) => Marker(
    point: p, width: 56, height: 64,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(99)),
          child: Text(label, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
      const Icon(Icons.location_on, color: AppColors.orange, size: 36),
    ]));

Marker truckPin(LatLng p) => Marker(
    point: p, width: 38, height: 38,
    child: Container(
        decoration: BoxDecoration(color: AppColors.ink, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
        child: const Icon(Icons.local_shipping, color: Colors.white, size: 18)));
