import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../services/geo_service.dart';
import '../../widgets/auto_map.dart';
import '../../widgets/common.dart';
import 'payment_screen.dart';
import 'review_screen.dart';

/// Shows a motorist's active request: waiting -> live tracking -> completed (pay) -> paid (review).
class TrackScreen extends StatefulWidget {
  final ServiceRequest req;
  const TrackScreen({super.key, required this.req});
  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  StreamSubscription? _sub;
  Map<String, dynamic> _mech = {};
  LatLng? _mechPt, _routeFrom;
  DateTime? _routeAt;
  RouteInfo? _route;
  static const _steps = [
    ['Request accepted', 'accepted'], ['Mechanic is on the way', 'enRoute'], ['Mechanic has arrived', 'arrived'],
    ['Service in progress', 'inProgress'], ['Service completed', 'completed']];
  static const _order = ['pending', 'accepted', 'enRoute', 'arrived', 'inProgress', 'completed', 'paid'];

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance.collection('Mechanics').doc(widget.req.mechanicId).snapshots().listen((s) {
      _mech = s.data() ?? {};
      final g = _mech['location'];
      if (g is GeoPoint) { _mechPt = LatLng(g.latitude, g.longitude); _maybeRoute(); }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  void _maybeRoute() {
    final m = _mechPt;
    if (m == null || widget.req.status == 'completed' || widget.req.status == 'paid') return;
    if (_routeFrom != null && _routeAt != null &&
        const Distance().as(LengthUnit.Meter, _routeFrom!, m) < 80 && DateTime.now().difference(_routeAt!) < const Duration(seconds: 30)) return;
    _routeFrom = m;
    _routeAt = DateTime.now();
    GeoService.route(m, widget.req.location).then((r) { if (mounted) setState(() => _route = r); });
  }

  Future<void> _contact(String scheme) async {
    final phone = ('${_mech['phone'] ?? ''}'.isNotEmpty ? '${_mech['phone']}' : widget.req.mechanicPhone);
    if (phone.isEmpty) { showSnack(context, 'No phone number on file (demo mechanics have none).', error: true); return; }
    await launchUrl(Uri(scheme: scheme, path: phone));
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Cancel request?'), content: const Text('The mechanic will be notified.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancel request', style: TextStyle(color: AppColors.red)))]));
    if (ok == true) await Db.cancelRequest(widget.req.id);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.req;
    switch (r.status) {
      case 'declined': return _declined(r);
      case 'completed': return _completed(r);
      case 'paid': return _paid(r);
      default: return _live(r);
    }
  }

  // ------------------------------------------------------------ pending + live tracking
  Widget _live(ServiceRequest r) {
    final p = context.pal;
    final pending = r.status == 'pending';
    final eta = _route != null ? _route!.minutes.ceil() : (r.d['etaMin'] as num?)?.toInt() ?? 0;
    final idx = _order.indexOf(r.status);
    return Scaffold(
      body: Column(children: [
        Expanded(flex: 5, child: Stack(children: [
          Positioned.fill(child: AutoMap(center: r.location, zoom: 14.5, route: _route?.points ?? const [],
              markers: [mePin(r.location), if (_mechPt != null) truckPin(_mechPt!)])),
          SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(99)),
                child: Text(pending ? 'Waiting for ${r.mechanicName}...' : r.status == 'arrived' || r.status == 'inProgress' ? 'Mechanic is at your location' : 'Mechanic arriving in $eta min',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
            const SizedBox(height: 10),
            AppCard(padding: const EdgeInsets.all(12), child: Row(children: [
              Avatar(initials(r.mechanicName), size: 44), const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Flexible(child: Text(r.mechanicName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))), const SizedBox(width: 6),
                  const Pill('Verified', color: AppColors.green, icon: Icons.verified)]),
                const SizedBox(height: 3),
                Row(children: [Stars(((_mech['rating'] as num?)?.toDouble()) ?? 0, size: 12), const SizedBox(width: 6),
                  Text(((_mech['reviewCount'] as num?) ?? 0) == 0 ? 'New' : ((_mech['rating'] as num).toDouble()).toStringAsFixed(1), style: const TextStyle(fontSize: 12))]),
              ])),
              if (!pending) Column(children: [Text('$eta min', style: const TextStyle(color: AppColors.orange, fontSize: 20, fontWeight: FontWeight.w800)), Text('ETA', style: TextStyle(color: p.muted, fontSize: 10))]),
            ])),
          ]))),
        ])),
        Expanded(flex: 5, child: Container(
          width: double.infinity,
          decoration: BoxDecoration(color: p.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text(pending ? 'Request sent' : '${r.mechanicName} has accepted your request', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (pending)
              Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.orange)), const SizedBox(width: 12),
                Expanded(child: Text('Waiting for the mechanic to accept. You can cancel at any time.', style: TextStyle(color: p.muted, fontSize: 13)))]))
            else
              for (final s in _steps) Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
                Icon(idx >= _order.indexOf(s[1]) ? Icons.check_circle : Icons.circle_outlined, size: 22, color: idx >= _order.indexOf(s[1]) ? AppColors.orange : p.border),
                const SizedBox(width: 12),
                Text(s[0], style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: idx >= _order.indexOf(s[1]) ? p.text : p.muted)),
              ])),
            const SizedBox(height: 10),
            Row(children: [
              if (!pending) ...[
                Expanded(child: _action(Icons.call, 'Call', AppColors.blue, () => _contact('tel'))), const SizedBox(width: 8),
                Expanded(child: _action(Icons.message, 'Message', AppColors.green, () => _contact('sms'))), const SizedBox(width: 8),
              ],
              if (r.status == 'pending' || r.status == 'accepted' || r.status == 'enRoute')
                Expanded(child: _action(Icons.close, 'Cancel', AppColors.red, _cancel)),
            ]),
          ])),
        )),
      ]),
    );
  }

  Widget _action(IconData i, String t, Color c, VoidCallback f) => InkWell(
        onTap: f, borderRadius: BorderRadius.circular(14),
        child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, size: 17, color: c), const SizedBox(width: 6),
              Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13))])),
      );

  // ------------------------------------------------------------ declined
  Widget _declined(ServiceRequest r) => Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cancel, size: 64, color: AppColors.red), const SizedBox(height: 14),
        const Text('Request declined', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), const SizedBox(height: 6),
        Text('${r.mechanicName} is unable to help right now. Please choose another mechanic.', textAlign: TextAlign.center, style: TextStyle(color: context.pal.muted)),
        const SizedBox(height: 24), PrimaryButton(label: 'Choose another mechanic', onPressed: () => Db.cancelRequest(r.id)),
      ]))));

  // ------------------------------------------------------------ completed -> pay
  Widget _completed(ServiceRequest r) {
    final p = context.pal;
    final started = r.ts('startedAt'), done = r.ts('completedAt') ?? DateTime.now();
    final dur = started == null ? null : done.difference(started).inMinutes;
    return Scaffold(body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      const SizedBox(height: 10),
      Center(child: Container(width: 84, height: 84, decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, color: AppColors.green, size: 52))),
      const SizedBox(height: 14),
      const Center(child: Text('Service Completed', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
      Center(child: Text('Your vehicle is back on the road!', style: TextStyle(color: p.muted))),
      const SizedBox(height: 20),
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Service Summary', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 6),
        KeyValue('Mechanic', r.mechanicName), KeyValue('Service', r.category),
        KeyValue('Date', DateFormat('d MMM yyyy').format(done)), KeyValue('Time', DateFormat('h:mm a').format(done)),
        if (dur != null) KeyValue('Duration', '$dur minutes'), KeyValue('Location', r.address.isEmpty ? '-' : r.address),
      ])),
      const SizedBox(height: 14),
      AppCard(color: p.soft, borderColor: AppColors.orange.withValues(alpha: 0.25), child: Column(children: [
        KeyValue('Callout Fee', kes(r.n('calloutFee'))), KeyValue('Labour', kes(r.n('labour'))), KeyValue('Parts', kes(r.n('parts'))),
        const Divider(), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total Due', style: TextStyle(fontWeight: FontWeight.w800)),
          Text(kes(r.total), style: const TextStyle(color: AppColors.orange, fontSize: 20, fontWeight: FontWeight.w800))]),
      ])),
      const SizedBox(height: 20),
      PrimaryButton(label: 'Pay with M-Pesa', icon: Icons.payments_outlined,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentScreen(req: r)))),
    ])));
  }

  // ------------------------------------------------------------ paid -> review
  Widget _paid(ServiceRequest r) => Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.verified, size: 68, color: AppColors.green), const SizedBox(height: 14),
        const Text('Payment received', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), const SizedBox(height: 6),
        Text('Ref: ${r.d['receipt'] ?? '-'}  -  ${kes(r.total)}', style: TextStyle(color: context.pal.muted)),
        const SizedBox(height: 28),
        PrimaryButton(label: 'Rate your experience', icon: Icons.star,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewScreen(req: r)))),
        const SizedBox(height: 10),
        PrimaryButton(label: 'Skip for now', outlined: true,
            onPressed: () => Db.setStatus(r.id, 'paid', {'reviewed': true, 'reviewSkipped': true})),
      ]))));
}
