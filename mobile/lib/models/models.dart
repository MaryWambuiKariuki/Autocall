import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../core/config.dart';
import '../core/theme.dart';

String kes(num n) => 'KES ${NumberFormat('#,##0').format(n)}';

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// Returns +2547XXXXXXXX (or +2541...) or null when the number is not a valid Kenyan mobile.
String? normalizeKePhone(String raw) {
  final s = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  final m = RegExp(r'^(?:\+?254|0)?([17]\d{8})$').firstMatch(s);
  return m == null ? null : '+254${m.group(1)}';
}

class AppUser {
  final String uid, name, email, phone, role;
  final Map<String, dynamic> vehicle;
  const AppUser({required this.uid, required this.name, required this.email, required this.phone,
      required this.role, this.vehicle = const {}});
  factory AppUser.fromMap(String id, Map<String, dynamic> m) => AppUser(
      uid: id, name: (m['name'] ?? '') as String, email: (m['email'] ?? '') as String,
      phone: (m['phone'] ?? '') as String, role: (m['role'] ?? 'motorist') as String,
      vehicle: Map<String, dynamic>.from(m['vehicle'] ?? {}));
}

class ProfileInput {
  final String name, phone, role;
  final String make, model, reg;                       // motorist (optional)
  final String businessName, specialization, idNumber; // mechanic
  final int experienceYears;
  const ProfileInput({required this.name, required this.phone, required this.role, this.make = '',
      this.model = '', this.reg = '', this.businessName = '', this.specialization = 'General Mechanic',
      this.idNumber = '', this.experienceYears = 0});
}

/// A mechanic - built either from the backend /api/recommend JSON or from a Firestore document.
class Mech {
  final String id, name, area, phone;
  final List<String> specializations;
  final double rating, lat, lng;
  final int reviewCount, completedJobs, experienceYears;
  final bool isVerified, isAvailable;
  double distanceKm;
  int etaMin, estFee;
  double score;
  String? badge;
  Mech({required this.id, required this.name, this.area = '', this.phone = '', this.specializations = const [],
      this.rating = 0, this.reviewCount = 0, this.completedJobs = 0, this.experienceYears = 0,
      this.isVerified = false, this.isAvailable = false, this.lat = 0, this.lng = 0, this.distanceKm = 0,
      this.etaMin = 0, this.estFee = 0, this.score = 0});

  factory Mech.fromJson(Map<String, dynamic> j) => Mech(
      id: j['id'], name: j['name'] ?? '', area: j['area'] ?? '', phone: j['phone'] ?? '',
      specializations: List<String>.from(j['specializations'] ?? []),
      rating: (j['rating'] as num?)?.toDouble() ?? 0, reviewCount: (j['reviewCount'] as num?)?.toInt() ?? 0,
      completedJobs: (j['completedJobs'] as num?)?.toInt() ?? 0,
      experienceYears: (j['experienceYears'] as num?)?.toInt() ?? 0, isVerified: true, isAvailable: true,
      lat: (j['lat'] as num).toDouble(), lng: (j['lng'] as num).toDouble(),
      distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0, etaMin: (j['etaMin'] as num?)?.toInt() ?? 0,
      estFee: (j['estFee'] as num?)?.toInt() ?? 0, score: (j['score'] as num?)?.toDouble() ?? 0);

  factory Mech.fromDoc(String id, Map<String, dynamic> m) {
    final g = m['location'];
    return Mech(
        id: id, name: m['name'] ?? '', area: m['area'] ?? '', phone: m['phone'] ?? '',
        specializations: List<String>.from(m['specializations'] ?? []),
        rating: (m['rating'] as num?)?.toDouble() ?? 0, reviewCount: (m['reviewCount'] as num?)?.toInt() ?? 0,
        completedJobs: (m['completedJobs'] as num?)?.toInt() ?? 0,
        experienceYears: (m['experienceYears'] as num?)?.toInt() ?? 0, isVerified: m['isVerified'] == true,
        isAvailable: m['isAvailable'] == true, lat: g is GeoPoint ? g.latitude : 0, lng: g is GeoPoint ? g.longitude : 0,
        estFee: (m['calloutFee'] as num?)?.toInt() ?? 0);
  }
  LatLng get point => LatLng(lat, lng);
  String get spec => specializations.isEmpty ? 'General Mechanic' : specializations.first;
}

/// What the motorist typed on the "What's wrong with your vehicle?" screen.
class Draft {
  String category, description, make, model, reg, address;
  double lat, lng;
  Draft({this.category = 'Other', this.description = '', this.make = '', this.model = '', this.reg = '',
      this.address = '', required this.lat, required this.lng});
}

class RouteInfo {
  final List<LatLng> points;
  final double minutes, km;
  final String source; // 'osrm' or 'straight_line' (fallback when the routing service is unavailable)
  RouteInfo(this.points, this.minutes, this.km, {this.source = 'osrm'});
  bool get degraded => source != 'osrm';
}

const kLiveStatuses = ['accepted', 'enRoute', 'arrived', 'inProgress'];

String statusLabel(String s) => const {
      'pending': 'Pending', 'accepted': 'Accepted', 'enRoute': 'En Route', 'arrived': 'Arrived',
      'inProgress': 'In Progress', 'completed': 'Awaiting Payment', 'paid': 'Completed',
      'declined': 'Declined', 'cancelled': 'Cancelled'}[s] ?? s;

Color statusColor(String s) {
  switch (s) {
    case 'paid': return AppColors.green;
    case 'completed': return AppColors.amber;
    case 'declined': case 'cancelled': return AppColors.red;
    case 'enRoute': return AppColors.blue;
    default: return AppColors.orange;
  }
}

class ServiceRequest {
  final String id;
  final Map<String, dynamic> d;
  ServiceRequest(this.id, this.d);
  factory ServiceRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> s) => ServiceRequest(s.id, s.data() ?? {});

  String get status => (d['status'] ?? 'pending') as String;
  String get motoristId => (d['motoristId'] ?? '') as String;
  String get mechanicId => (d['mechanicId'] ?? '') as String;
  String get motoristName => (d['motoristName'] ?? '') as String;
  String get motoristPhone => (d['motoristPhone'] ?? '') as String;
  String get mechanicName => (d['mechanicName'] ?? '') as String;
  String get mechanicPhone => (d['mechanicPhone'] ?? '') as String;
  String get category => (d['category'] ?? 'Other') as String;
  String get description => (d['description'] ?? '') as String;
  String get address => (d['address'] ?? '') as String;
  Map<String, dynamic> get vehicle => Map<String, dynamic>.from(d['vehicle'] ?? {});
  String get vehicleLabel => '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}'.trim();
  String get reg => (vehicle['reg'] ?? '') as String;
  LatLng get location {
    final g = d['location'];
    return g is GeoPoint ? LatLng(g.latitude, g.longitude) : AppConfig.defaultCenter;
  }
  DateTime? ts(String k) { final v = d[k]; return v is Timestamp ? v.toDate() : null; }
  DateTime get createdAt => ts('createdAt') ?? DateTime.now();
  double n(String k) => (d[k] as num?)?.toDouble() ?? 0;
  double get total => n('total');
  double get estFee => n('estFee');
  double get distanceKm => n('distanceKm');
  bool get reviewed => d['reviewed'] == true;
  int get rating => (d['rating'] as num?)?.toInt() ?? 0;
  bool get isLive => kLiveStatuses.contains(status);
  /// Active for the motorist = still needs attention in the "Requests" tab.
  bool get activeForMotorist => status != 'cancelled' && !(status == 'paid' && reviewed);
}

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 30) return '${d.inDays} days ago';
  return DateFormat('d MMM yyyy').format(t);
}
