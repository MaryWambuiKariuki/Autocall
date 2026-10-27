import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';
import 'api_service.dart';

class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);
  @override
  String toString() => message;
}

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;
  static const badLogin = 'Incorrect email or password. Please try again.';

  static String _msg(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential': case 'wrong-password': case 'user-not-found': case 'invalid-email': return badLogin;
      case 'too-many-requests': return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed': return 'No internet connection.';
      case 'email-already-in-use': return 'That email is already registered. Try logging in.';
      case 'weak-password': return 'Password is too weak (minimum 8 characters).';
      case 'invalid-verification-code': return 'The code is incorrect.';
      case 'invalid-phone-number': return 'That phone number is not valid.';
      case 'account-exists-with-different-credential': return 'An account already exists with this email using another sign-in method.';
      default: return e.message ?? 'Something went wrong (${e.code}).';
    }
  }

  static Future<void> signInWithIdentifier(String identifier, String password) async {
    var email = identifier.trim();
    if (!email.contains('@')) {
      final phone = normalizeKePhone(email);
      if (phone == null) throw AuthFailure('Enter a valid email or Kenyan phone number.');
      try { email = await ApiService.resolveEmail(phone) ?? ''; } catch (_) { email = ''; }
      if (email.isEmpty) throw AuthFailure(badLogin);
    }
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_msg(e));
    }
  }

  static Future<void> registerEmail({required ProfileInput p, required String email, required String password}) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      await cred.user!.updateDisplayName(p.name);
      await saveProfile(cred.user!.uid, email.trim(), p);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_msg(e));
    }
  }

  static Future<void> signInWithGoogle() async {
    try {
      final acct = await GoogleSignIn().signIn();
      if (acct == null) throw AuthFailure('Google sign-in was cancelled.');
      final a = await acct.authentication;
      await _auth.signInWithCredential(GoogleAuthProvider.credential(accessToken: a.accessToken, idToken: a.idToken));
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_msg(e));
    } catch (e) {
      throw AuthFailure('Google sign-in failed. Check the SHA-1 key in Firebase. ($e)');
    }
  }

  static String messageFor(FirebaseAuthException e) => _msg(e);

  /// Creates users/{uid} (+ mechanics/{uid} for mechanics). Used by e-mail, Google and phone sign-ups.
  static Future<void> saveProfile(String uid, String email, ProfileInput p) async {
    final b = _db.batch();
    b.set(_db.collection('Users').doc(uid), {
      'name': p.name, 'email': email, 'phone': p.phone, 'role': p.role,
      if (p.role == 'motorist') 'vehicle': {'make': p.make, 'model': p.model, 'reg': p.reg},
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (p.role == 'mechanic') {
      b.set(_db.collection('Mechanics').doc(uid), {
        'name': p.businessName.isEmpty ? p.name : p.businessName, 'ownerName': p.name, 'phone': p.phone, 'area': '',
        'specializations': [p.specialization], 'experienceYears': p.experienceYears,
        'rating': 0, 'reviewCount': 0, 'avgResponseMin': 0, 'completedJobs': 0, 'calloutFee': 800,
        'isAvailable': false, 'isVerified': false, 'verificationStatus': 'not_submitted', 'isSeed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await b.commit();
  }
}
