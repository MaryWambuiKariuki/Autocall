import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';

class SessionProvider extends ChangeNotifier {
  User? user;
  AppUser? profile;
  bool ready = false;
  StreamSubscription? _auth, _prof;

  SessionProvider() {
    _auth = FirebaseAuth.instance.authStateChanges().listen((u) {
      user = u;
      _prof?.cancel();
      profile = null;
      if (u == null) { ready = true; notifyListeners(); return; }
      ready = false;
      notifyListeners();
      _prof = FirebaseFirestore.instance.collection('Users').doc(u.uid).snapshots().listen((s) {
        profile = s.exists ? AppUser.fromMap(s.id, s.data()!) : null;
        ready = true;
        notifyListeners();
      }, onError: (_) { ready = true; notifyListeners(); });
    });
  }

  Future<void> signOut() async {
    try { await GoogleSignIn().signOut(); } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() { _auth?.cancel(); _prof?.cancel(); super.dispose(); }
}
