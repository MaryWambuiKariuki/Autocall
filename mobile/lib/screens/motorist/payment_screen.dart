import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/session_provider.dart';
import '../../services/api_service.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

class PaymentScreen extends StatefulWidget {
  final ServiceRequest req;
  const PaymentScreen({super.key, required this.req});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _phone = TextEditingController();
  StreamSubscription? _sub;
  String _state = 'idle'; // idle | waiting | success | failed
  String? _receipt, _msg;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _phone.text = context.read<SessionProvider>().profile?.phone ?? '';
  }

  @override
  void dispose() { _sub?.cancel(); _phone.dispose(); super.dispose(); }

  Future<void> _pay() async {
    if (normalizeKePhone(_phone.text) == null) { setState(() => _msg = 'Enter a valid Safaricom number, e.g. 0712 345 678'); return; }
    setState(() { _busy = true; _msg = null; });
    try {
      await ApiService.stkPush(widget.req.id, _phone.text);
      _listen();
      setState(() => _state = 'waiting');
    } on ApiException catch (e) {
      setState(() => _msg = e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  void _listen() {
    _sub?.cancel();
    _sub = FirebaseFirestore.instance.collection('Payments')
        .where('requestId', isEqualTo: widget.req.id).where('motoristId', isEqualTo: Db.uid).snapshots().listen((s) {
      if (s.docs.isEmpty) return;
      final l = s.docs.map((d) => d.data()).toList();
      int ms(Map<String, dynamic> m) => (m['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      l.sort((a, b) => ms(b).compareTo(ms(a)));
      final latest = l.first;
      if (latest['status'] == 'success') {
        setState(() { _state = 'success'; _receipt = latest['receipt'] as String?; });
      } else if (latest['status'] == 'failed') {
        setState(() { _state = 'failed'; _msg = (latest['resultDesc'] ?? 'Payment was not completed.').toString(); });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal, r = widget.req;
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Payment', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ORDER SUMMARY', style: TextStyle(color: p.muted, fontSize: 11, fontWeight: FontWeight.w700)), const SizedBox(height: 8),
          Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.mechanicName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(r.category, style: TextStyle(color: p.muted, fontSize: 12))])),
            Text(kes(r.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))]),
        ])),
        const SizedBox(height: 14),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.4))),
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(12)), alignment: Alignment.center,
                  child: const Text('M-PESA', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('M-Pesa', style: TextStyle(fontWeight: FontWeight.w700)), Text('Safaricom mobile money', style: TextStyle(fontSize: 12))])),
              const Icon(Icons.check_circle, color: AppColors.green),
            ])),
        ])),
        const SizedBox(height: 14),
        AppCard(child: LabeledField(label: 'M-Pesa Phone Number', controller: _phone, hint: '+254 7XX XXX XXX', keyboard: TextInputType.phone,
            helper: 'A push notification will be sent to this number to confirm payment.', enabled: _state != 'waiting' && _state != 'success')),
        const SizedBox(height: 14),
        if (_state == 'waiting') AppCard(color: p.soft, child: Row(children: [
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.orange)), const SizedBox(width: 14),
          Expanded(child: Text('Check your phone and enter your M-Pesa PIN to approve ${kes(r.total)}...', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)))])),
        if (_state == 'success') AppCard(color: AppColors.green.withValues(alpha: 0.1), borderColor: AppColors.green.withValues(alpha: 0.4), child: Column(children: [
          const Icon(Icons.check_circle, color: AppColors.green, size: 48), const SizedBox(height: 8),
          const Text('Payment Successful', style: TextStyle(color: AppColors.green, fontSize: 18, fontWeight: FontWeight.w800)),
          Text('Ref: ${_receipt ?? '-'}', style: TextStyle(color: p.muted, fontSize: 12)), const SizedBox(height: 14),
          PrimaryButton(label: 'Continue', color: AppColors.green, onPressed: () => Navigator.pop(context))])),
        if (_msg != null && _state != 'success') Padding(padding: const EdgeInsets.only(bottom: 12), child: ErrorBox(_msg!)),
        if (_state == 'idle' || _state == 'failed') PrimaryButton(label: _state == 'failed' ? 'Try again - ${kes(r.total)}' : 'Pay ${kes(r.total)}', loading: _busy, onPressed: _pay),
        if (_state == 'waiting') TextButton(onPressed: () => setState(() { _sub?.cancel(); _state = 'idle'; }), child: const Text("I didn't get a prompt - try again")),
        const SizedBox(height: 14),
        Row(children: [const Icon(Icons.lock, size: 14, color: AppColors.green), const SizedBox(width: 6),
          Expanded(child: Text('Secured by Autocall - payment is processed by Safaricom M-Pesa.', style: TextStyle(color: p.muted, fontSize: 11.5)))]),
      ]),
    );
  }
}
