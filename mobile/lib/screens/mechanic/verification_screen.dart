import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

/// FR5: mechanics submit identity, certification and registration information for admin verification.
/// Photos are compressed and stored inside the Verifications document (no paid Cloud Storage needed).
class VerificationScreen extends StatefulWidget {
  final String status; // not_submitted | pending | approved | rejected
  const VerificationScreen({super.key, required this.status});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController(), _reg = TextEditingController(), _cert = TextEditingController();
  String? _idPhoto, _certPhoto, _error;
  bool _busy = false;
  static const _maxBytes = 380000; // keeps both photos well under Firestore's 1 MiB document limit

  @override
  void dispose() { _id.dispose(); _reg.dispose(); _cert.dispose(); super.dispose(); }

  Future<String?> _pick() async {
    final src = await showModalBottomSheet<ImageSource>(context: context, showDragHandle: true, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Camera'), onTap: () => Navigator.pop(c, ImageSource.camera)),
      ListTile(leading: const Icon(Icons.photo_library), title: const Text('Gallery'), onTap: () => Navigator.pop(c, ImageSource.gallery))])));
    if (src == null) return null;
    final x = await ImagePicker().pickImage(source: src, maxWidth: 900, imageQuality: 50);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    if (bytes.length > _maxBytes) {
      if (mounted) showSnack(context, 'That photo is too large (${(bytes.length / 1024).round()} KB). Use a smaller or lower-quality photo.', error: true);
      return null;
    }
    return base64Encode(bytes);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_idPhoto == null) { setState(() => _error = 'Attach a photo of your National ID.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      final f = FirebaseFirestore.instance, uid = Db.uid, b = f.batch();
      b.set(f.collection('Verifications').doc(uid), {
        'mechanicId': uid, 'idNumber': _id.text.trim(), 'registrationNo': _reg.text.trim(), 'certification': _cert.text.trim(),
        'idPhoto': _idPhoto, 'certPhoto': _certPhoto ?? '', 'status': 'pending', 'submittedAt': FieldValue.serverTimestamp()});
      b.update(f.collection('Mechanics').doc(uid), {'verificationStatus': 'pending', 'updatedAt': FieldValue.serverTimestamp()});
      await b.commit();
      if (!mounted) return;
      showSnack(context, 'Submitted. An administrator will review your details.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not submit: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _photo(String label, String? b64, VoidCallback pick, {bool required = false}) {
    final p = context.pal;
    return Expanded(child: GestureDetector(onTap: pick, child: Container(
      height: 120, decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
      child: b64 == null
          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_a_photo_outlined, color: AppColors.orange), const SizedBox(height: 6),
              Text('$label${required ? ' *' : ''}', style: TextStyle(color: p.muted, fontSize: 12), textAlign: TextAlign.center)])
          : ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(base64Decode(b64), fit: BoxFit.cover, width: double.infinity)),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal, st = widget.status;
    final locked = st == 'pending' || st == 'approved';
    return Scaffold(
      appBar: AppBar(title: const Text('Mechanic Verification', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        AppCard(color: locked ? AppColors.green.withValues(alpha: 0.10) : p.soft, child: Row(children: [
          Icon(st == 'approved' ? Icons.verified : st == 'pending' ? Icons.hourglass_top : Icons.assignment_ind_outlined, color: st == 'approved' ? AppColors.green : AppColors.orange),
          const SizedBox(width: 12),
          Expanded(child: Text(st == 'approved' ? 'You are verified. Motorists can see and request you.'
              : st == 'pending' ? 'Submitted - an administrator is reviewing your details.'
              : st == 'rejected' ? 'Your last submission was rejected. Please correct your details and submit again.'
              : 'Submit your identity, registration and certification details. Only verified mechanics appear to motorists.', style: const TextStyle(fontSize: 13))),
        ])),
        if (!locked) Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 18),
          LabeledField(label: 'National ID number *', controller: _id, hint: '7-8 digits', keyboard: TextInputType.number,
              validator: (v) => RegExp(r'^\d{7,8}$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid Kenyan ID number (7-8 digits)'),
          const SizedBox(height: 14),
          LabeledField(label: 'Business registration / licence no.', controller: _reg, hint: 'If you operate a registered garage'),
          const SizedBox(height: 14),
          LabeledField(label: 'Certification', controller: _cert, hint: 'e.g. trade test certificate name / number'),
          const SizedBox(height: 16),
          const Text('Photos (max ~380 KB each)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            _photo('National ID photo', _idPhoto, () async { final r = await _pick(); if (r != null) setState(() => _idPhoto = r); }, required: true),
            const SizedBox(width: 12),
            _photo('Certificate photo', _certPhoto, () async { final r = await _pick(); if (r != null) setState(() => _certPhoto = r); }),
          ]),
          if (_error != null) ...[const SizedBox(height: 14), ErrorBox(_error!)],
          const SizedBox(height: 20),
          PrimaryButton(label: 'Submit for verification', loading: _busy, onPressed: _submit),
          const SizedBox(height: 8),
          Text('Your documents are visible only to you and Autocall administrators.', style: TextStyle(color: p.muted, fontSize: 11.5)),
        ])),
      ]),
    );
  }
}
