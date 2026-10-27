import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/session_provider.dart';
import '../../services/db.dart';
import '../../services/geo_service.dart';
import '../../widgets/auto_map.dart';
import '../../widgets/common.dart';
import '../notifications.dart';
import '../profile_screen.dart';
import 'verification_screen.dart';

/// Holds the mechanic's live data (their requests + their mechanic document) and shares GPS while online.
class MechanicData extends ChangeNotifier {
  final String uid;
  List<ServiceRequest> requests = [];
  Map<String, dynamic> doc = {};
  StreamSubscription? _a, _b;
  StreamSubscription<Position>? _pos;
  LatLng? myPos;

  MechanicData(this.uid) {
    _a = Db.mechanicRequests(uid).listen((l) { requests = l; _sync(); notifyListeners(); });
    _b = FirebaseFirestore.instance.collection('Mechanics').doc(uid).snapshots().listen((s) { doc = s.data() ?? {}; _sync(); notifyListeners(); });
  }

  bool get verified => doc['isVerified'] == true;
  bool get available => doc['isAvailable'] == true;
  bool get suspended => doc['isSuspended'] == true;
  String get status => (doc['verificationStatus'] ?? 'not_submitted') as String;
  List<ServiceRequest> get pending => requests.where((r) => r.status == 'pending').toList();
  ServiceRequest? get active { for (final r in requests) { if (r.isLive) return r; } return null; }
  List<ServiceRequest> get history => requests.where((r) => r.status == 'completed' || r.status == 'paid').toList();
  double get earningsToday {
    final now = DateTime.now();
    return requests.where((r) => r.status == 'paid' && (r.ts('paidAt') ?? DateTime(2000)).day == now.day && (r.ts('paidAt') ?? DateTime(2000)).month == now.month)
        .fold(0.0, (s, r) => s + r.total);
  }

  Future<void> setAvailable(bool v) async {
    await FirebaseFirestore.instance.collection('Mechanics').doc(uid).update({'isAvailable': v, 'updatedAt': FieldValue.serverTimestamp()});
    if (v) await pushLocation();
  }

  /// One-off GPS fix used by the navigation map.
  Future<LatLng?> refreshPos() async {
    final p = await GeoService.position();
    if (p != null) { myPos = LatLng(p.latitude, p.longitude); notifyListeners(); }
    return myPos;
  }

  Future<void> pushLocation() async {
    final p = await GeoService.position();
    if (p != null) {
      myPos = LatLng(p.latitude, p.longitude);
      notifyListeners();
      await FirebaseFirestore.instance.collection('Mechanics').doc(uid)
          .update({'location': GeoPoint(p.latitude, p.longitude), 'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  // Share location while online or while on a job (so the motorist can track the mechanic).
  void _sync() {
    final need = available || active != null;
    if (need && _pos == null) {
      _pos = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 30)).listen((p) {
        myPos = LatLng(p.latitude, p.longitude);
        FirebaseFirestore.instance.collection('Mechanics').doc(uid)
            .update({'location': GeoPoint(p.latitude, p.longitude), 'updatedAt': FieldValue.serverTimestamp()}).catchError((_) {});
      }, onError: (_) {});
    } else if (!need && _pos != null) {
      _pos!.cancel();
      _pos = null;
    }
  }

  @override
  void dispose() { _a?.cancel(); _b?.cancel(); _pos?.cancel(); super.dispose(); }
}

class MechanicShell extends StatelessWidget {
  const MechanicShell({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
      create: (_) => MechanicData(Db.uid), child: const _Tabs());
}

class _Tabs extends StatefulWidget {
  const _Tabs();
  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    final d = context.watch<MechanicData>();
    final p = context.pal;
    return Scaffold(
      body: IndexedStack(index: _i, children: [const _Home(), const _Requests(), const _Jobs(), const ProfileScreen()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i, backgroundColor: p.navBg, indicatorColor: AppColors.orange.withValues(alpha: 0.16),
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: AppColors.orange), label: 'Home'),
          NavigationDestination(icon: Badge(isLabelVisible: d.pending.isNotEmpty, label: Text('${d.pending.length}'), child: const Icon(Icons.assignment_outlined)),
              selectedIcon: const Icon(Icons.assignment, color: AppColors.orange), label: 'Requests'),
          const NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping, color: AppColors.orange), label: 'Jobs'),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: AppColors.orange), label: 'Profile'),
        ],
      ),
    );
  }
}

Future<void> _accept(BuildContext c, ServiceRequest r, MechanicData d) async {
  if (!d.verified || d.suspended) { showSnack(c, 'Your account must be verified (and not suspended) to accept jobs.', error: true); return; }
  if (d.active != null) { showSnack(c, 'Finish your current job first.', error: true); return; }
  await Db.setStatus(r.id, 'accepted', {'acceptedAt': FieldValue.serverTimestamp()});
}

// ------------------------------------------------------------------ Home / dashboard
class _Home extends StatelessWidget {
  const _Home();
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final d = context.watch<MechanicData>();
    final me = context.watch<SessionProvider>().profile;
    final first = d.pending.isEmpty ? null : d.pending.first;
    Widget tile(IconData i, String label, String val, Color c) => Expanded(child: AppCard(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, color: c), const SizedBox(height: 8), Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: p.muted, fontSize: 12))])));
    return SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hello, ${(me?.name ?? '').split(' ').first}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          Text(d.available ? 'You are online' : 'You are offline', style: TextStyle(color: d.available ? AppColors.green : p.muted, fontWeight: FontWeight.w600))])),
        const NotifBell(),
        Switch(value: d.available, activeColor: AppColors.orange, onChanged: (v) {
          if (v && (!d.verified || d.suspended)) { showSnack(context, 'You can go online once an admin has verified your account.', error: true); return; }
          d.setAvailable(v);
        }),
      ]),
      if (!d.verified || d.suspended) ...[
        const SizedBox(height: 12),
        AppCard(color: AppColors.amber.withValues(alpha: 0.12), borderColor: AppColors.amber.withValues(alpha: 0.4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.hourglass_top, color: AppColors.amber), const SizedBox(width: 12),
            Expanded(child: Text(d.suspended ? 'Your account is suspended. Contact support.'
                : d.status == 'pending' ? 'Verification pending - an administrator is reviewing your details. You will appear to motorists once approved.'
                : d.status == 'rejected' ? 'Your verification was rejected. Please correct your details and submit again.'
                : 'Submit your ID, registration and certification details so an administrator can verify you.', style: const TextStyle(fontSize: 12.5)))]),
          if (!d.suspended && (d.status == 'not_submitted' || d.status == 'rejected'))
            Padding(padding: const EdgeInsets.only(top: 10), child: PrimaryButton(label: 'Submit verification details', icon: Icons.assignment_ind_outlined,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VerificationScreen(status: d.status))))),
        ])),
      ],
      const SizedBox(height: 16),
      Row(children: [tile(Icons.notifications_active, 'New Requests', '${d.pending.length}', AppColors.orange), const SizedBox(width: 12),
        tile(Icons.build, 'Active Job', d.active == null ? '0' : '1', AppColors.blue)]),
      const SizedBox(height: 12),
      Row(children: [tile(Icons.check_circle, 'Completed Jobs', '${(d.doc['completedJobs'] as num?)?.toInt() ?? 0}', AppColors.green), const SizedBox(width: 12),
        tile(Icons.star, 'Avg. Rating', ((d.doc['reviewCount'] as num?) ?? 0) == 0 ? 'New' : ((d.doc['rating'] as num).toDouble()).toStringAsFixed(1), AppColors.amber)]),
      if (first != null) ...[
        const SectionTitle('Incoming Request'),
        _requestCard(context, first, d),
      ],
      const SectionTitle("Today's Earnings"),
      AppCard(child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(kes(d.earningsToday), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          Text('from paid jobs today', style: TextStyle(color: p.muted, fontSize: 12))])),
        const Icon(Icons.payments_outlined, color: AppColors.green, size: 34)])),
    ]));
  }
}

Widget _requestCard(BuildContext context, ServiceRequest r, MechanicData d) {
  final p = context.pal;
  return AppCard(padding: EdgeInsets.zero, borderColor: AppColors.orange.withValues(alpha: 0.5), child: Column(children: [
    Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: const Text('New Assistance Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
    Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Avatar(initials(r.motoristName), size: 44, color: Colors.blueGrey), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.motoristName, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(r.address.isEmpty ? 'Location shared' : r.address, style: TextStyle(color: p.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)])),
        Pill('${r.distanceKm.toStringAsFixed(1)} km', color: AppColors.amber)]),
      const SizedBox(height: 12),
      Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r.category} problem', style: const TextStyle(fontWeight: FontWeight.w700)),
            if (r.description.isNotEmpty) Text(r.description, style: TextStyle(color: p.muted, fontSize: 12.5))])),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: PrimaryButton(label: 'Decline', outlined: true, color: AppColors.red, onPressed: () => Db.setStatus(r.id, 'declined', {'declinedAt': FieldValue.serverTimestamp()}))),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: PrimaryButton(label: 'Accept Request', onPressed: () => _accept(context, r, d))),
      ]),
    ])),
  ]));
}

// ------------------------------------------------------------------ Requests tab + details
class _Requests extends StatelessWidget {
  const _Requests();
  @override
  Widget build(BuildContext context) {
    final d = context.watch<MechanicData>();
    return SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Requests', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      if (d.pending.isEmpty) const Padding(padding: EdgeInsets.only(top: 60), child: EmptyState(Icons.inbox_outlined, 'No new requests', 'Stay online - motorists near you will appear here.')),
      for (final r in d.pending) Padding(padding: const EdgeInsets.only(bottom: 12), child: AppCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: d, child: _Details(id: r.id)))),
        child: Row(children: [Avatar(initials(r.motoristName), size: 44, color: Colors.blueGrey), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.motoristName, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${r.category} - ${r.distanceKm.toStringAsFixed(1)} km away', style: TextStyle(color: context.pal.muted, fontSize: 12))])),
          const Pill('Pending', color: AppColors.amber)]))),
    ]));
  }
}

class _Details extends StatelessWidget {
  final String id;
  const _Details({required this.id});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final d = context.watch<MechanicData>();
    final matches = d.requests.where((x) => x.id == id).toList();
    if (matches.isEmpty) return Scaffold(appBar: AppBar(), body: const EmptyState(Icons.info_outline, 'Request no longer available', ''));
    final r = matches.first;
    return Scaffold(
      appBar: AppBar(title: const Text('Request Details', style: TextStyle(fontWeight: FontWeight.w800)), actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Pill(statusLabel(r.status), color: statusColor(r.status)))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(child: Row(children: [Avatar(initials(r.motoristName), size: 50, color: Colors.blueGrey), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.motoristName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(r.motoristPhone.isEmpty ? 'Verified user' : r.motoristPhone, style: TextStyle(color: p.muted, fontSize: 12))]))])),
        const SizedBox(height: 12),
        AppCard(child: Column(children: [KeyValue('Make', r.vehicle['make']?.toString() ?? '-'), KeyValue('Model', r.vehicle['model']?.toString() ?? '-'), KeyValue('Reg.', r.reg.isEmpty ? '-' : r.reg)])),
        const SizedBox(height: 12),
        AppCard(color: p.soft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${r.category} issue', style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4),
          Text(r.description.isEmpty ? 'No description provided.' : r.description, style: TextStyle(color: p.muted))])),
        const SizedBox(height: 12),
        AppCard(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(r.address.isEmpty ? 'Motorist location' : r.address, style: const TextStyle(fontWeight: FontWeight.w600))),
            Pill('${r.distanceKm.toStringAsFixed(1)} km', color: AppColors.amber)]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(height: 160, child: AutoMap(center: r.location, zoom: 15, interactive: false, markers: [mePin(r.location)]))),
        ])),
        const SizedBox(height: 18),
        if (r.status == 'pending') Row(children: [
          Expanded(child: PrimaryButton(label: 'Decline', outlined: true, color: AppColors.red, onPressed: () async { await Db.setStatus(r.id, 'declined'); if (context.mounted) Navigator.pop(context); })),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: PrimaryButton(label: 'Accept Request', onPressed: () async { await _accept(context, r, d); if (context.mounted && d.active != null) Navigator.pop(context); })),
        ]),
      ]),
    );
  }
}

// ------------------------------------------------------------------ Jobs tab (active job + history)
class _Jobs extends StatelessWidget {
  const _Jobs();
  static const _steps = [['Request accepted', 'acceptedAt', 'accepted'], ['En route to motorist', 'enRouteAt', 'enRoute'], ['Arrived at location', 'arrivedAt', 'arrived'],
    ['Service in progress', 'startedAt', 'inProgress'], ['Service completed', 'completedAt', 'completed']];
  static const _order = ['accepted', 'enRoute', 'arrived', 'inProgress', 'completed'];
  static const _next = {'accepted': ['enRoute', 'Start trip (I am on the way)', 'enRouteAt'], 'enRoute': ['arrived', 'Mark as Arrived', 'arrivedAt'], 'arrived': ['inProgress', 'Start service', 'startedAt']};

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final d = context.watch<MechanicData>();
    final a = d.active;
    return SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Jobs', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      if (a == null) const AppCard(child: Text('No active job. Accept a request to get started.'))
      else ...[
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text('Job #${a.id.substring(0, 6).toUpperCase()}', style: TextStyle(color: p.muted, fontSize: 12))), Pill(statusLabel(a.status), color: statusColor(a.status))]),
          const SizedBox(height: 10),
          Row(children: [Avatar(initials(a.motoristName), size: 46, color: Colors.blueGrey), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.motoristName, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${a.vehicleLabel} ${a.reg}'.trim(), style: TextStyle(color: p.muted, fontSize: 12)), Text(a.category, style: TextStyle(color: p.muted, fontSize: 12))]))]),
        ])),
        const SizedBox(height: 12),
        _JobMap(a: a, d: d),
        const SizedBox(height: 12),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Job Progress', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8),
          for (final s in _steps) Builder(builder: (_) {
            final done = _order.indexOf(a.status) >= _order.indexOf(s[2]);
            final t = a.ts(s[1]);
            return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
              Icon(done ? Icons.check_circle : Icons.circle_outlined, color: done ? AppColors.orange : p.border), const SizedBox(width: 12),
              Expanded(child: Text(s[0], style: TextStyle(fontWeight: FontWeight.w600, color: done ? p.text : p.muted))),
              if (t != null) Text(DateFormat('h:mm a').format(t), style: TextStyle(color: p.muted, fontSize: 11.5))]));
          }),
        ])),
        const SizedBox(height: 14),
        if (_next[a.status] != null)
          PrimaryButton(label: _next[a.status]![1], onPressed: () => Db.setStatus(a.id, _next[a.status]![0], {_next[a.status]![2]: FieldValue.serverTimestamp()}))
        else if (a.status == 'inProgress')
          PrimaryButton(label: 'Complete service & bill', icon: Icons.receipt_long, onPressed: () => _complete(context, a)),
      ],
      const SectionTitle('Completed jobs'),
      if (d.history.isEmpty) Text('Nothing here yet.', style: TextStyle(color: p.muted)),
      for (final r in d.history) Padding(padding: const EdgeInsets.only(bottom: 10), child: AppCard(child: Row(children: [
        Avatar(initials(r.motoristName), size: 40, color: Colors.blueGrey), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.motoristName, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('${r.category} - ${DateFormat('d MMM').format(r.createdAt)}', style: TextStyle(color: p.muted, fontSize: 12))])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(kes(r.total), style: const TextStyle(fontWeight: FontWeight.w800)), Pill(statusLabel(r.status), color: statusColor(r.status))])]))),
    ]));
  }

  Future<void> _complete(BuildContext context, ServiceRequest a) async {
    final callout = TextEditingController(text: '${a.estFee.toInt()}'), labour = TextEditingController(text: '0'), parts = TextEditingController(text: '0');
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Bill the motorist'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        LabeledField(label: 'Callout fee (KES)', controller: callout, keyboard: TextInputType.number), const SizedBox(height: 10),
        LabeledField(label: 'Labour (KES)', controller: labour, keyboard: TextInputType.number), const SizedBox(height: 10),
        LabeledField(label: 'Parts (KES)', controller: parts, keyboard: TextInputType.number)]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Complete'))]));
    if (ok != true) return;
    final co = double.tryParse(callout.text) ?? 0, la = double.tryParse(labour.text) ?? 0, pa = double.tryParse(parts.text) ?? 0;
    await Db.setStatus(a.id, 'completed', {'calloutFee': co, 'labour': la, 'parts': pa, 'total': co + la + pa, 'completedAt': FieldValue.serverTimestamp()});
  }
}


/// FR14 / route optimisation: route from the mechanic to the motorist, ETA, and a hand-off to any installed maps app.
class _JobMap extends StatefulWidget {
  final ServiceRequest a;
  final MechanicData d;
  const _JobMap({required this.a, required this.d});
  @override
  State<_JobMap> createState() => _JobMapState();
}

class _JobMapState extends State<_JobMap> {
  RouteInfo? _route;
  LatLng? _from;
  DateTime? _at;
  bool _busy = false;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _fetch()); }

  @override
  void didUpdateWidget(covariant _JobMap old) { super.didUpdateWidget(old); _fetch(); }

  Future<void> _fetch() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      final me = widget.d.myPos ?? await widget.d.refreshPos();
      if (me == null || !mounted) return;
      if (_from != null && _at != null && const Distance().as(LengthUnit.Meter, _from!, me) < 80 &&
          DateTime.now().difference(_at!) < const Duration(seconds: 30)) { return; }
      _from = me;
      _at = DateTime.now();
      final r = await GeoService.route(me, widget.a.location);
      if (mounted) setState(() => _route = r);
    } finally {
      _busy = false;
    }
  }

  Future<void> _openMaps() async {
    final l = widget.a.location;
    final ok = await launchUrl(Uri.parse('geo:${l.latitude},${l.longitude}?q=${l.latitude},${l.longitude}(${Uri.encodeComponent(widget.a.motoristName)})'),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) showSnack(context, 'No maps app found on this phone.', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal, dest = widget.a.location, me = widget.d.myPos;
    final line = _route?.points ?? (me == null ? <LatLng>[] : [me, dest]);
    return AppCard(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.alt_route, color: AppColors.orange), const SizedBox(width: 8),
        Expanded(child: Text(_route == null ? (me == null ? 'Getting your location...' : 'Calculating route...') : '${_route!.km.toStringAsFixed(1)} km - about ${_route!.minutes.ceil()} min',
            style: const TextStyle(fontWeight: FontWeight.w700))),
        if (_route?.degraded == true) const Pill('Direct line', color: AppColors.amber),
      ]),
      if (_route?.degraded == true) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Road routing is unavailable right now - showing the direct line and an estimate.', style: TextStyle(color: p.muted, fontSize: 11.5))),
      const SizedBox(height: 10),
      ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(height: 210, child: AutoMap(center: me ?? dest, zoom: 14, route: line,
          markers: [mePin(dest, label: 'Motorist'), if (me != null) truckPin(me)]))),
      const SizedBox(height: 10),
      PrimaryButton(label: 'Open in maps app', icon: Icons.navigation_outlined, outlined: true, onPressed: _openMaps),
    ]));
  }
}
