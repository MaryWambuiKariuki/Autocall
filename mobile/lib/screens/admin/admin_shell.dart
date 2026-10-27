import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../profile_screen.dart';

typedef Row_ = Map<String, dynamic>;

class AdminData extends ChangeNotifier {
  List<Row_> users = [], mechanics = [], requests = [], reviews = [];
  final _subs = <StreamSubscription>[];
  AdminData() {
    void watch(String c, void Function(List<Row_>) set) => _subs.add(FirebaseFirestore.instance.collection(c).snapshots().listen((s) {
          set(s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
          notifyListeners();
        }, onError: (_) {}));
    watch('Users', (l) => users = l);
    watch('Mechanics', (l) => mechanics = l);
    watch('ServiceRequests', (l) => requests = l);
    watch('Reviews', (l) => reviews = l);
  }
  List<Row_> get realMechanics => mechanics.where((m) => m['isSeed'] != true).toList();
  List<Row_> get pendingVerif => realMechanics.where((m) => m['verificationStatus'] == 'pending').toList();
  List<Row_> get activeReqs => requests.where((r) => kLiveStatuses.contains(r['status']) || r['status'] == 'pending').toList();
  List<Row_> get flagged => reviews.where((r) => r['isFlagged'] == true && r['status'] == 'open').toList()
    ..sort((a, b) => (a['flagLevel'] == 'high' ? 0 : 1).compareTo(b['flagLevel'] == 'high' ? 0 : 1));
  int get today => requests.where((r) {
        final t = r['createdAt']; if (t is! Timestamp) return false; final n = DateTime.now(), d = t.toDate();
        return d.year == n.year && d.month == n.month && d.day == n.day; }).length;
  @override
  void dispose() { for (final s in _subs) { s.cancel(); } super.dispose(); }
}

class AdminShell extends StatelessWidget {
  const AdminShell({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(create: (_) => AdminData(), child: const _Tabs());
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
    final p = context.pal;
    return Scaffold(
      body: IndexedStack(index: _i, children: [_Dash(goTo: (v) => setState(() => _i = v)), const _Mechanics(), const _Requests(), const _Reviews()]),
      bottomNavigationBar: NavigationBar(selectedIndex: _i, backgroundColor: p.navBg, indicatorColor: AppColors.orange.withValues(alpha: 0.16),
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: AppColors.orange), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping, color: AppColors.orange), label: 'Mechanics'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment, color: AppColors.orange), label: 'Requests'),
          NavigationDestination(icon: Icon(Icons.star_outline), selectedIcon: Icon(Icons.star, color: AppColors.orange), label: 'Reviews'),
        ]),
    );
  }
}

Widget _initials(String n, {Color? c}) => Avatar(initials(n), size: 42, color: c ?? Colors.blueGrey);

Future<void> _verify(BuildContext context, Row_ m) async {
  final fs = FirebaseFirestore.instance, id = '${m['id']}';
  final v = (await fs.collection('Verifications').doc(id).get()).data() ?? {};
  if (!context.mounted) return;
  Widget photo(String label, dynamic b64) => (b64 == null || '$b64'.isEmpty)
      ? Padding(padding: const EdgeInsets.only(top: 6), child: Text('$label: not provided', style: const TextStyle(fontSize: 12)))
      : Padding(padding: const EdgeInsets.only(top: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(height: 4),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode('$b64'), height: 150, width: double.infinity, fit: BoxFit.cover))]));
  final res = await showDialog<String>(context: context, builder: (c) => AlertDialog(
    title: Text('${m['name']}'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      KeyValue('Owner', '${m['ownerName'] ?? '-'}'), KeyValue('Phone', '${m['phone'] ?? '-'}'),
      KeyValue('Speciality', ((m['specializations'] as List?)?.join(', ')) ?? '-'), KeyValue('Experience', '${m['experienceYears'] ?? 0} yrs'),
      KeyValue('National ID no.', '${v['idNumber'] ?? '-'}'), KeyValue('Registration / licence', '${(v['registrationNo'] ?? '').toString().isEmpty ? '-' : v['registrationNo']}'),
      KeyValue('Certification', '${(v['certification'] ?? '').toString().isEmpty ? '-' : v['certification']}'), KeyValue('Status', '${m['verificationStatus']}'),
      photo('National ID photo', v['idPhoto']), photo('Certificate photo', v['certPhoto'])])),
    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
      TextButton(onPressed: () => Navigator.pop(c, 'reject'), child: const Text('Reject', style: TextStyle(color: AppColors.red))),
      TextButton(onPressed: () => Navigator.pop(c, 'approve'), child: const Text('Approve', style: TextStyle(color: AppColors.green)))]));
  if (res == null) return;
  final ok = res == 'approve', me = FirebaseAuth.instance.currentUser!.uid, b = fs.batch();
  b.update(fs.collection('Mechanics').doc(id), ok
      ? {'isVerified': true, 'verificationStatus': 'approved', 'verifiedAt': FieldValue.serverTimestamp()}
      : {'isVerified': false, 'isAvailable': false, 'verificationStatus': 'rejected'});
  b.set(fs.collection('Verifications').doc(id), {'status': ok ? 'approved' : 'rejected', 'reviewedBy': me, 'reviewedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  b.set(fs.collection('Notifications').doc(), {'userId': id, 'title': ok ? 'You are verified' : 'Verification rejected',
    'body': ok ? 'An administrator approved your account. Go online to receive requests.' : 'Please correct your details and submit again.',
    'type': 'verification', 'requestId': null, 'read': false, 'fromUid': me, 'createdAt': FieldValue.serverTimestamp()});
  await b.commit();
}

class _Dash extends StatelessWidget {
  final void Function(int) goTo;
  const _Dash({required this.goTo});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final d = context.watch<AdminData>();
    Widget tile(IconData i, String label, int n, {Color bg = const Color(0xFF2A2A2A), Color fg = Colors.white, VoidCallback? onTap}) => Expanded(child: GestureDetector(onTap: onTap, child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14), margin: const EdgeInsets.all(4), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [Icon(i, color: fg.withValues(alpha: 0.85), size: 20), const SizedBox(height: 6), Text('$n', style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 11))]))));
    const amber = Color(0xFFFEF3C7);
    return ListView(padding: EdgeInsets.zero, children: [
      Container(color: const Color(0xFF1A1A1A), padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 16), child: Column(children: [
        Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Administrator', style: TextStyle(color: Colors.white70, fontSize: 12)), Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800))])),
          InkWell(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(), body: const ProfileScreen()))),
              child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.settings, color: Colors.white)))]),
        const SizedBox(height: 12),
        Row(children: [tile(Icons.people, 'Users', d.users.length, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChangeNotifierProvider.value(value: d, child: const _UsersScreen())))), tile(Icons.build, 'Mechanics', d.realMechanics.length), tile(Icons.hourglass_bottom, 'Pending', d.pendingVerif.length, bg: amber, fg: AppColors.amber)]),
        Row(children: [tile(Icons.settings, 'Active Jobs', d.activeReqs.length, bg: AppColors.orange), tile(Icons.event_note, 'Today', d.today), tile(Icons.flag, 'Flagged', d.flagged.length, bg: amber, fg: AppColors.amber)]),
      ])),
      Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle('Pending Verifications', action: 'View all (${d.pendingVerif.length})', onAction: () => goTo(1)),
        if (d.pendingVerif.isEmpty) Text('No mechanics waiting for verification.', style: TextStyle(color: p.muted)),
        for (final m in d.pendingVerif.take(3)) Padding(padding: const EdgeInsets.only(bottom: 10), child: AppCard(child: Row(children: [
          _initials('${m['name']}'), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${m['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(((m['specializations'] as List?)?.join(', ')) ?? '', style: TextStyle(color: p.muted, fontSize: 12))])),
          ElevatedButton(onPressed: () => _verify(context, m), style: ElevatedButton.styleFrom(backgroundColor: amber, foregroundColor: AppColors.amber, elevation: 0), child: const Text('Review'))]))),
        SectionTitle('Active Service Requests', action: 'View all (${d.activeReqs.length})', onAction: () => goTo(2)),
        if (d.activeReqs.isEmpty) Text('No active requests.', style: TextStyle(color: p.muted)),
        for (final r in d.activeReqs.take(3)) _reqTile(context, r),
      ])),
    ]);
  }
}

Widget _reqTile(BuildContext context, Row_ r) => Padding(padding: const EdgeInsets.only(bottom: 10), child: AppCard(child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('#${('${r['id']}').substring(0, 6).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w800)),
        Text('${r['motoristName']} -> ${r['mechanicName']}', style: TextStyle(color: context.pal.muted, fontSize: 12))])),
      Pill(statusLabel('${r['status']}'), color: statusColor('${r['status']}'))])));

class _Mechanics extends StatelessWidget {
  const _Mechanics();
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final d = context.watch<AdminData>();
    final list = [...d.mechanics]..sort((a, b) => ('${a['isSeed']}').compareTo('${b['isSeed']}'));
    return SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Mechanics', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      Text('${d.realMechanics.length} registered - ${d.mechanics.length - d.realMechanics.length} demo/listed', style: TextStyle(color: p.muted)),
      const SizedBox(height: 12),
      for (final m in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: AppCard(child: Row(children: [
        _initials('${m['name']}', c: m['isSeed'] == true ? AppColors.ink : AppColors.orange), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${m['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(m['isSeed'] == true ? '${m['source'] ?? 'demo'}' : '${m['verificationStatus']}', style: TextStyle(color: p.muted, fontSize: 12))])),
        if (m['isSeed'] == true) const Pill('Demo', color: AppColors.blue)
        else if (m['isSuspended'] == true) TextButton(onPressed: () => FirebaseFirestore.instance.collection('Mechanics').doc(m['id']).update({'isSuspended': false}), child: const Text('Reinstate'))
        else if (m['verificationStatus'] == 'approved') const Pill('Verified', color: AppColors.green)
        else if (m['verificationStatus'] == 'pending') ElevatedButton(onPressed: () => _verify(context, m), child: const Text('Review'))
        else Pill('${m['verificationStatus']}'.replaceAll('_', ' '), color: AppColors.amber)]))),
    ]));
  }
}

class _Requests extends StatelessWidget {
  const _Requests();
  @override
  Widget build(BuildContext context) {
    final d = context.watch<AdminData>();
    final l = [...d.requests]..sort((a, b) => ((b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0).compareTo((a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
    return SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Service Requests', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)), const SizedBox(height: 12),
      if (l.isEmpty) const EmptyState(Icons.assignment_outlined, 'No requests yet', ''),
      for (final r in l) _reqTile(context, r),
    ]));
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews();
  Future<void> _act(BuildContext context, Row_ r, String action) async {
    final db = FirebaseFirestore.instance;
    if (action == 'action') {
      final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: const Text('Suspend mechanic?'), content: Text('${r['mechanicName']} will be taken offline and cannot accept jobs until reinstated.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Suspend', style: TextStyle(color: AppColors.red)))]));
      if (ok != true) return;
      await db.collection('Mechanics').doc('${r['mechanicId']}').update({'isSuspended': true, 'isAvailable': false});
      await db.collection('Reviews').doc('${r['id']}').update({'status': 'actioned'});
    } else if (action == 'dismiss') {
      await db.collection('Reviews').doc('${r['id']}').update({'status': 'dismissed'});
    } else {
      await showDialog(context: context, builder: (c) => AlertDialog(title: Text('${r['motoristName']} -> ${r['mechanicName']}'),
        content: Text('"${r['comment']}"\n\nRating: ${r['rating']}/5\nNLP: ${r['sentimentLabel']} (${(((r['sentimentConfidence'] as num?) ?? 0) * 100).round()}%)\nModel: ${r['sentimentModel']}'),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final d = context.watch<AdminData>();
    return SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Flagged Reviews', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      Text('AI-assisted - a human decides every action', style: TextStyle(color: p.muted, fontSize: 12)), const SizedBox(height: 12),
      if (d.flagged.isEmpty) const EmptyState(Icons.verified_outlined, 'Nothing to review', 'Negative or suspicious reviews will appear here.'),
      for (final r in d.flagged) Builder(builder: (_) {
        final high = r['flagLevel'] == 'high';
        final c = high ? AppColors.red : AppColors.amber;
        final conf = (((r['sentimentConfidence'] as num?) ?? 0) * 100).round();
        return Padding(padding: const EdgeInsets.only(bottom: 14), child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: 0.3))),
            child: Row(children: [Icon(Icons.psychology, color: c, size: 20), const SizedBox(width: 8),
              Expanded(child: Text('NLP: ${'${r['sentimentLabel']}'.toUpperCase()} sentiment - $conf% confidence', style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12))),
              Pill(high ? 'Requires Review' : 'Low Priority', color: c)])),
          const SizedBox(height: 10),
          Row(children: [_initials('${r['motoristName']}'), const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${r['motoristName']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('-> ${r['mechanicName']}', style: TextStyle(color: p.muted, fontSize: 12)), Stars((r['rating'] as num?)?.toDouble() ?? 0, size: 12)]))]),
          const SizedBox(height: 10),
          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: c, width: 3))),
              child: Text('"${r['comment']}"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _btn('Take Action', AppColors.red, () => _act(context, r, 'action'))), const SizedBox(width: 8),
            Expanded(child: _btn('Review', AppColors.amber, () => _act(context, r, 'review'))), const SizedBox(width: 8),
            Expanded(child: _btn('Dismiss', p.muted, () => _act(context, r, 'dismiss')))]),
        ])));
      }),
    ]));
  }

  Widget _btn(String t, Color c, VoidCallback f) => InkWell(onTap: f, borderRadius: BorderRadius.circular(12),
      child: Container(padding: const EdgeInsets.symmetric(vertical: 11), alignment: Alignment.center,
          decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12))));
}


/// FR23: administrators can monitor all registered users.
class _UsersScreen extends StatelessWidget {
  const _UsersScreen();
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final l = [...context.watch<AdminData>().users]..sort((a, b) => '${a['role']}${a['name']}'.compareTo('${b['role']}${b['name']}'));
    return Scaffold(
      appBar: AppBar(title: Text('Users (${l.length})', style: const TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final u in l) Padding(padding: const EdgeInsets.only(bottom: 10), child: AppCard(child: Row(children: [
          _initials('${u['name']}'), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${u['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${u['email'] ?? ''}  ${u['phone'] ?? ''}'.trim(), style: TextStyle(color: p.muted, fontSize: 12))])),
          Pill('${u['role']}', color: u['role'] == 'admin' ? AppColors.red : u['role'] == 'mechanic' ? AppColors.blue : AppColors.orange)]))),
      ]),
    );
  }
}
