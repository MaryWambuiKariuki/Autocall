import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/session_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';

const kSpecializations = ['General Mechanic', 'Electrical', 'Bodywork', 'Tyre & Alignment', 'AC Repair',
  'Engine Overhaul', 'Transmission', 'Exhaust & Brakes'];

/// Used for e-mail sign-up AND (completeMode) for finishing a profile after Google / phone sign-in.
class RegisterScreen extends StatefulWidget {
  final bool completeMode;
  const RegisterScreen({super.key, this.completeMode = false});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _phone = TextEditingController(), _email = TextEditingController(),
      _pw = TextEditingController(), _pw2 = TextEditingController(), _make = TextEditingController(),
      _model = TextEditingController(), _reg = TextEditingController(), _biz = TextEditingController(),
      _years = TextEditingController();
  String _role = 'motorist', _spec = kSpecializations.first;
  bool _agree = false, _busy = false, _hide = true;
  String? _error;
  bool get _needsEmail => widget.completeMode && (FirebaseAuth.instance.currentUser?.email ?? '').isEmpty;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    if (widget.completeMode && u != null) {
      _name.text = u.displayName ?? '';
      _email.text = u.email ?? '';
      _phone.text = u.phoneNumber ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _pw, _pw2, _make, _model, _reg, _biz, _years]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_agree) { setState(() => _error = 'Please accept the Terms of Service and Privacy Policy.'); return; }
    final phone = normalizeKePhone(_phone.text)!;
    final input = ProfileInput(
        name: _name.text.trim(), phone: phone, role: _role, make: _make.text.trim(), model: _model.text.trim(),
        reg: _reg.text.trim().toUpperCase(), businessName: _biz.text.trim(), specialization: _spec,
        experienceYears: int.tryParse(_years.text.trim()) ?? 0);
    setState(() { _busy = true; _error = null; });
    try {
      if (widget.completeMode) {
        final u = FirebaseAuth.instance.currentUser!;
        await AuthService.saveProfile(u.uid, (u.email ?? '').isNotEmpty ? u.email! : _email.text.trim(), input);
      } else {
        await AuthService.registerEmail(p: input, email: _email.text, password: _pw.text);
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save your profile: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final comp = widget.completeMode;
    return Scaffold(
      appBar: AppBar(
        leading: comp ? null : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        automaticallyImplyLeading: false,
        actions: [if (comp) TextButton(onPressed: () => context.read<SessionProvider>().signOut(), child: const Text('Sign out'))],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(comp ? 'Complete your profile' : 'Create Account', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              Text(comp ? 'Just a few details to finish setting up' : 'Join Autocall to get roadside help', style: TextStyle(color: p.muted)),
              const SizedBox(height: 20),
              Wrap(spacing: 10, children: [
                for (final r in const [['motorist', 'I need a mechanic'], ['mechanic', 'I am a mechanic']])
                  ChoiceChip(
                    label: Text(r[1]), selected: _role == r[0], selectedColor: AppColors.orange.withValues(alpha: 0.18),
                    side: BorderSide(color: _role == r[0] ? AppColors.orange : p.border),
                    onSelected: (_) => setState(() => _role = r[0]),
                  ),
              ]),
              const SizedBox(height: 18),
              LabeledField(label: 'Full Name', controller: _name, hint: 'e.g. Sarah Kamau', validator: _req),
              const SizedBox(height: 14),
              LabeledField(label: 'Phone Number', controller: _phone, hint: '+254 7XX XXX XXX', keyboard: TextInputType.phone,
                  validator: (v) => normalizeKePhone(v ?? '') == null ? 'Enter a valid Kenyan number' : null),
              if (!comp || _needsEmail) ...[
                const SizedBox(height: 14),
                LabeledField(label: 'Email Address', controller: _email, hint: 'sarah@email.com', keyboard: TextInputType.emailAddress,
                    validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) ? 'Enter a valid email' : null),
              ],
              if (!comp) ...[
                const SizedBox(height: 14),
                LabeledField(label: 'Password', controller: _pw, hint: 'Min. 8 characters', obscure: _hide,
                    suffix: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility, color: p.muted), onPressed: () => setState(() => _hide = !_hide)),
                    validator: (v) => (v ?? '').length < 8 ? 'At least 8 characters' : null),
                const SizedBox(height: 14),
                LabeledField(label: 'Confirm Password', controller: _pw2, hint: 'Re-enter password', obscure: _hide,
                    validator: (v) => v != _pw.text ? 'Passwords do not match' : null),
              ],
              if (_role == 'motorist') ...[
                const SizedBox(height: 20),
                Row(children: [Expanded(child: Divider(color: p.border)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('VEHICLE INFO (OPTIONAL)', style: TextStyle(color: p.muted, fontSize: 10.5, fontWeight: FontWeight.w700))),
                  Expanded(child: Divider(color: p.border))]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: LabeledField(label: 'Make', controller: _make, hint: 'e.g. Toyota')), const SizedBox(width: 12),
                  Expanded(child: LabeledField(label: 'Model', controller: _model, hint: 'e.g. Fielder'))]),
                const SizedBox(height: 14),
                LabeledField(label: 'Registration Number', controller: _reg, hint: 'e.g. KCA 123A'),
              ] else ...[
                const SizedBox(height: 20),
                Row(children: [Expanded(child: Divider(color: p.border)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('BUSINESS DETAILS', style: TextStyle(color: p.muted, fontSize: 10.5, fontWeight: FontWeight.w700))),
                  Expanded(child: Divider(color: p.border))]),
                const SizedBox(height: 14),
                LabeledField(label: 'Garage / business name', controller: _biz, hint: 'e.g. James Auto Care', validator: _req),
                const SizedBox(height: 14),
                const Text('Main specialization', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _spec, items: [for (final s in kSpecializations) DropdownMenuItem(value: s, child: Text(s))],
                  onChanged: (v) => setState(() => _spec = v!),
                  decoration: InputDecoration(filled: true, fillColor: p.field,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.border))),
                ),
                const SizedBox(height: 14),
                LabeledField(label: 'Years of experience', controller: _years, hint: 'e.g. 5', keyboard: TextInputType.number),
                const SizedBox(height: 8),
                Text('After registering, submit your ID, registration and certification details from the Home tab. An administrator verifies mechanics before they appear to motorists.', style: TextStyle(color: p.muted, fontSize: 12)),
              ],
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Checkbox(value: _agree, activeColor: AppColors.orange, onChanged: (v) => setState(() => _agree = v ?? false)),
                Expanded(child: Padding(padding: const EdgeInsets.only(top: 12),
                    child: Text('I agree to the Terms of Service and Privacy Policy, and to Autocall using my location to find nearby mechanics.', style: TextStyle(color: p.muted, fontSize: 12)))),
              ]),
              if (_error != null) ...[const SizedBox(height: 10), ErrorBox(_error!)],
              const SizedBox(height: 16),
              PrimaryButton(label: comp ? 'Finish' : 'Create Account', loading: _busy, onPressed: _submit),
              if (!comp) ...[
                const SizedBox(height: 14),
                Center(child: GestureDetector(onTap: () => Navigator.pop(context),
                    child: Text.rich(TextSpan(text: 'Already have an account? ', style: TextStyle(color: p.muted),
                        children: const [TextSpan(text: 'Log In', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700))])))),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
