import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

/// Firestore access. Collection names follow Chapter 4:
/// Users, Mechanics, ServiceRequests, Reviews, Payments, Notifications, Verifications.
class Db {
  static final _f = FirebaseFirestore.instance;
  static String get uid => FirebaseAuth.instance.currentUser!.uid;

  static List<ServiceRequest> _sorted(QuerySnapshot<Map<String, dynamic>> s) {
    final l = s.docs.map(ServiceRequest.fromDoc).toList();
    l.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return l;
  }

  // Queries filter on ONE field only (so no composite index is needed); sorting happens on the device.
  static Stream<List<ServiceRequest>> motoristRequests() =>
      _f.collection('ServiceRequests').where('motoristId', isEqualTo: uid).snapshots().map(_sorted);

  static Stream<List<ServiceRequest>> mechanicRequests(String mechId) =>
      _f.collection('ServiceRequests').where('mechanicId', isEqualTo: mechId).snapshots().map(_sorted);

  static Future<bool> motoristHasActive() async {
    final s = await _f.collection('ServiceRequests').where('motoristId', isEqualTo: uid).get();
    return s.docs.map(ServiceRequest.fromDoc).any((r) => r.activeForMotorist);
  }

  // ---------------------------------------------------------------- notifications (FR15)
  static Stream<QuerySnapshot<Map<String, dynamic>>> notifications() =>
      _f.collection('Notifications').where('userId', isEqualTo: uid).snapshots();

  /// Best-effort: a failed notification must never break the main action.
  static Future<void> notify(String userId, String title, String body, String type, {String? requestId}) async {
    if (userId.isEmpty || userId == uid) return;
    try {
      await _f.collection('Notifications').add({
        'userId': userId, 'title': title, 'body': body, 'type': type, 'requestId': requestId,
        'read': false, 'fromUid': uid, 'createdAt': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  static Future<void> markRead(String id) => _f.collection('Notifications').doc(id).update({'read': true});

  // ---------------------------------------------------------------- service requests
  static Future<String> createRequest(Draft d, Mech m, AppUser me) async {
    final doc = _f.collection('ServiceRequests').doc();
    await doc.set({
      'motoristId': me.uid, 'motoristName': me.name, 'motoristPhone': me.phone,
      'mechanicId': m.id, 'mechanicName': m.name, 'mechanicPhone': m.phone,
      'category': d.category, 'description': d.description,
      'vehicle': {'make': d.make, 'model': d.model, 'reg': d.reg},
      'location': GeoPoint(d.lat, d.lng), 'address': d.address,
      'distanceKm': m.distanceKm, 'etaMin': m.etaMin, 'estFee': m.estFee,
      'status': 'pending', 'reviewed': false, 'createdAt': FieldValue.serverTimestamp(),
    });
    await notify(m.id, 'New assistance request', '${me.name} needs help with a ${d.category.toLowerCase()} problem.', 'request', requestId: doc.id);
    return doc.id;
  }

  static const _msgs = {
    'accepted': ['Request accepted', 'accepted your request.'],
    'enRoute': ['Mechanic on the way', 'is on the way to your location.'],
    'arrived': ['Mechanic has arrived', 'has arrived at your location.'],
    'inProgress': ['Service started', 'has started working on your vehicle.'],
    'completed': ['Service completed', 'finished the job. Please review the bill and pay with M-Pesa.'],
    'declined': ['Request declined', 'could not take your request. Please choose another mechanic.'],
  };

  /// Updates the request status and notifies the other party.
  static Future<void> setStatus(String id, String status, [Map<String, dynamic>? extra]) async {
    final ref = _f.collection('ServiceRequests').doc(id);
    final before = ServiceRequest.fromDoc(await ref.get());
    await ref.update({'status': status, ...?extra});
    if (before.status == status) return;
    if (status == 'cancelled') {
      await notify(before.mechanicId, 'Request cancelled', '${before.motoristName} cancelled the request.', 'status', requestId: id);
    } else if (_msgs.containsKey(status)) {
      await notify(before.motoristId, _msgs[status]![0], '${before.mechanicName} ${_msgs[status]![1]}', 'status', requestId: id);
    }
  }

  static Future<void> cancelRequest(String id) =>
      setStatus(id, 'cancelled', {'cancelledAt': FieldValue.serverTimestamp()});
}
