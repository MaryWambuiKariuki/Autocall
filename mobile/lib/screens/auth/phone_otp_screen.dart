import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../core/theme.dart';

class PhoneOtpScreen extends StatefulWidget {
  const PhoneOtpScreen({super.key});
  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  final _phone = TextEditingController(), _code = TextEditingController();
  String? _verificationId, _error;
  bool _busy = false;

  @override
  void dispose() { _phone.dispose(); _code.dispose(); super.dispose(); }

  void _done() { if (mounted) Navigator.of(context).popUntil((r) => r.isFirst); }

  Future<void> _send() async {
    final phone = normalizeKePhone(_phone.text);
    if (phone == null) { setState(() => _error = 'Enter a valid Kenyan number, e.g. 0712 345 678'); return; }
    setState(() { _busy = true; _error = null; });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (cred) async {          // instant verification / auto-retrieval on some phones
        try { await FirebaseAuth.instance.signInWithCredential(cred); _done(); } catch (_) {}
      },
      verificationFailed: (e) { if (mounted) setState(() { _busy = false; _error = AuthService.messageFor(e); }); },
      codeSent: (id, _) { if (mounted) setState(() { _verificationId = id; _busy = false; }); },
      codeAutoRetrievalTimeout: (id) { _verificationId ??= id; },
    );
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) { setState(() => _error = 'Enter the 6-digit code.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      final cred = PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: _code.text.trim());
      await FirebaseAuth.instance.signInWithCredential(cred);
      _done();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() { _busy = false; _error = AuthService.messageFor(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final step2 = _verificationId != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Phone sign-in')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(step2 ? 'Enter the code' : 'Verify your number', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(step2 ? 'We sent a 6-digit code by SMS to ${_phone.text}.' : 'We will send you a one-time password (OTP) by SMS.',
                style: TextStyle(color: context.pal.muted)),
            const SizedBox(height: 24),
            if (!step2)
              LabeledField(label: 'Phone Number', controller: _phone, hint: '+254 7XX XXX XXX', keyboard: TextInputType.phone)
            else
              LabeledField(label: '6-digit code', controller: _code, hint: '123456', keyboard: TextInputType.number),
            const SizedBox(height: 20),
            PrimaryButton(label: step2 ? 'Verify and continue' : 'Send code', loading: _busy, onPressed: step2 ? _verify : _send),
            if (step2) TextButton(onPressed: () => setState(() { _verificationId = null; _code.clear(); }), child: const Text('Use a different number')),
            if (_error != null) ...[const SizedBox(height: 14), ErrorBox(_error!)],
            const SizedBox(height: 16),
            Text('New here? After verifying you will be asked to complete your profile.', style: TextStyle(color: context.pal.muted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
