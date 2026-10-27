import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static Future<Map<String, dynamic>> _call(String method, String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final headers = {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'};
    if (auth) {
      final t = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (t != null) headers['Authorization'] = 'Bearer $t';
    }
    final uri = Uri.parse('${AppConfig.backendUrl}$path');
    try {
      final res = method == 'GET'
          ? await http.get(uri, headers: headers).timeout(const Duration(seconds: 30))
          : await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 45));
      final data = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400) throw ApiException((data['error'] ?? 'Server error (${res.statusCode})').toString());
      return data;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Could not reach the Autocall server. Is the backend running? ($e)');
    }
  }

  static Future<List<Mech>> recommend(Draft d) async {
    final r = await _call('POST', '/api/recommend', body: {'lat': d.lat, 'lng': d.lng, 'category': d.category});
    final list = (r['mechanics'] as List).map((e) => Mech.fromJson(Map<String, dynamic>.from(e))).toList();
    return list;
  }

  /// Route + ETA from the Flask backend (which calls OSRM). Falls back to a straight line if the backend fails.
  static Future<RouteInfo> route(double fLat, double fLng, double tLat, double tLng) async {
    final r = await _call('POST', '/api/route', body: {'fromLat': fLat, 'fromLng': fLng, 'toLat': tLat, 'toLng': tLng});
    final pts = (r['points'] as List).map((e) => LatLng((e[0] as num).toDouble(), (e[1] as num).toDouble())).toList();
    return RouteInfo(pts, (r['minutes'] as num).toDouble(), (r['km'] as num).toDouble(), source: '${r['source'] ?? 'osrm'}');
  }

  static Future<String> reverse(double lat, double lng) async {
    final r = await _call('POST', '/api/geocode/reverse', body: {'lat': lat, 'lng': lng});
    return '${r['name'] ?? 'Current location'}';
  }

  static Future<String?> resolveEmail(String phone) async {
    final r = await _call('POST', '/api/auth/resolve', body: {'identifier': phone}, auth: false);
    return r['email'] as String?;
  }

  static Future<void> submitReview(String requestId, int rating, List<String> tags, String comment) =>
      _call('POST', '/api/reviews', body: {'requestId': requestId, 'rating': rating, 'tags': tags, 'comment': comment});

  static Future<void> stkPush(String requestId, String phone) =>
      _call('POST', '/api/mpesa/stkpush', body: {'requestId': requestId, 'phone': phone});
}
