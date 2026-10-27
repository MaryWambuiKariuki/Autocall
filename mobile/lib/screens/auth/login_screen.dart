import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import 'phone_otp_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController(), _pw = TextEditingController();
  bool _hide = true, _busy = false, _gBusy = false;
  String? _error;

  @override
  void dispose() { _id.dispose(); _pw.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (_id.text.trim().isEmpty || _pw.text.isEmpty) { setState(() => _error = 'Enter your email/phone and password.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      await AuthService.signInWithIdentifier(_id.text, _pw.text);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _google() async {
    setState(() { _gBusy = true; _error = null; });
    try {
      await AuthService.signInWithGoogle();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
    if (mounted) setState(() => _gBusy = false);
  }

  Future<void> _forgot() async {
    final c = TextEditingController(text: _id.text.contains('@') ? _id.text : '');
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: LabeledField(label: 'Email address', controller: c, keyboard: TextInputType.emailAddress),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Send link')),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) showSnack(context, 'If that email is registered, a reset link has been sent.');
    } on FirebaseAuthException catch (e) {
      if (mounted) showSnack(context, AuthService.messageFor(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.location_on, color: Colors.white)),
              const SizedBox(width: 10),
              const Text('Autocall', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 36),
            const Text('Welcome back', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            Text('Sign in to access roadside assistance', style: TextStyle(color: p.muted)),
            const SizedBox(height: 28),
            LabeledField(label: 'Email or Phone Number', controller: _id, hint: 'Enter your email or phone', keyboard: TextInputType.emailAddress),
            const SizedBox(height: 16),
            LabeledField(label: 'Password', controller: _pw, hint: 'Enter your password', obscure: _hide,
                suffix: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility, color: p.muted), onPressed: () => setState(() => _hide = !_hide))),
            Align(alignment: Alignment.centerRight,
                child: TextButton(onPressed: _forgot, child: const Text('Forgot password?', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600)))),
            PrimaryButton(label: 'Log In', loading: _busy, onPressed: _login),
            const SizedBox(height: 18),
            Row(children: [Expanded(child: Divider(color: p.border)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or continue with', style: TextStyle(color: p.muted, fontSize: 12))),
              Expanded(child: Divider(color: p.border))]),
            const SizedBox(height: 18),
            PrimaryButton(label: 'Continue with Google', icon: Icons.g_mobiledata, outlined: true, loading: _gBusy, onPressed: _google),
            const SizedBox(height: 10),
            PrimaryButton(label: 'Use phone number (OTP)', icon: Icons.sms_outlined, outlined: true,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PhoneOtpScreen()))),
            if (_error != null) ...[const SizedBox(height: 16), ErrorBox(_error!)],
            const SizedBox(height: 28),
            Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text("Don't have an account? ", style: TextStyle(color: p.muted)),
              GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text('Sign Up', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700))),
            ])),
          ]),
        ),
      ),
    );
  }
}
