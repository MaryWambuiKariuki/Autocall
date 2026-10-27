import 'package:latlong2/latlong.dart';

class AppConfig {
  /// Pass your ngrok / server URL at run time:
  ///   flutter run --dart-define=BACKEND_URL=https://xxxx.ngrok-free.app
  static const backendUrl =
      String.fromEnvironment('BACKEND_URL', defaultValue: 'http://10.0.2.2:5000');
  static const appPackage = 'com.autocall.autocall';
  static const defaultCenter = LatLng(-1.2921, 36.8219); // Nairobi CBD fallback
}
