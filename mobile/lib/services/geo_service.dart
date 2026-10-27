import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import 'api_service.dart';

/// GPS position from the phone + map services (routing / reverse geocoding) that the Flask backend
/// obtains from free OpenStreetMap services (OSRM, Nominatim).
class GeoService {

  static Future<Position?> position() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    } catch (_) {
      return null;
    }
  }

  /// Area name via the backend (Nominatim). Never throws.
  static Future<String> reverse(double lat, double lng) async {
    try { return await ApiService.reverse(lat, lng); } catch (_) { return 'Current location'; }
  }

  /// Route via the backend (OSRM). Returns null only if the backend itself is unreachable.
  static Future<RouteInfo?> route(LatLng a, LatLng b) async {
    try { return await ApiService.route(a.latitude, a.longitude, b.latitude, b.longitude); } catch (_) { return null; }
  }
}
