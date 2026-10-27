import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/db.dart';
import '../widgets/common.dart';

/// Bell icon with an unread badge (opens the notification centre).
class NotifBell extends StatefulWidget {
  const NotifBell({super.key});
  @override
  State<NotifBell> createState() => _NotifBellState();
}

class _NotifBellState extends State<NotifBell> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _s = Db.notifications();
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _s,
        builder: (c, snap) {
          final n = (snap.data?.docs ?? []).where((d) => d.data()['read'] != true).length;
          return IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            icon: Badge(isLabelVisible: n > 0, label: Text('$n'), child: const Icon(Icons.notifications_none)),
          );
        },
      );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _s = Db.notifications();

  IconData _icon(String t) => t == 'payment' ? Icons.payments_outlined : t == 'review' ? Icons.star_outline : t == 'request' ? Icons.assignment_outlined : Icons.local_shipping_outlined;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800))),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _s,
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.orange));
          final l = snap.data!.docs.toList();
          int ms(QueryDocumentSnapshot<Map<String, dynamic>> d) => (d.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          l.sort((a, b) => ms(b).compareTo(ms(a)));
          if (l.isEmpty) return const EmptyState(Icons.notifications_off_outlined, 'No notifications yet', 'Request updates and payments will appear here.');
          return ListView(padding: const EdgeInsets.all(16), children: [
            for (final d in l) Padding(padding: const EdgeInsets.only(bottom: 10), child: AppCard(
              onTap: () => Db.markRead(d.id),
              color: d.data()['read'] == true ? null : p.soft,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(_icon('${d.data()['type']}'), color: AppColors.orange), const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${d.data()['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2), Text('${d.data()['body']}', style: TextStyle(color: p.muted, fontSize: 12.5)),
                  const SizedBox(height: 4),
                  Text(timeAgo(((d.data()['createdAt'] as Timestamp?)?.toDate()) ?? DateTime.now()), style: TextStyle(color: p.muted, fontSize: 11)),
                ])),
              ]),
            )),
          ]);
        },
      ),
    );
  }
}

/// Wraps a shell: shows an in-app banner the moment a new notification arrives (real-time via Firestore).
class NotifyHost extends StatefulWidget {
  final Widget child;
  const NotifyHost({super.key, required this.child});
  @override
  State<NotifyHost> createState() => _NotifyHostState();
}

class _NotifyHostState extends State<NotifyHost> {
  StreamSubscription? _sub;
  final _seen = <String>{};
  bool _first = true;

  @override
  void initState() {
    super.initState();
    _sub = Db.notifications().listen((s) {
      for (final d in s.docs) {
        if (_seen.add(d.id) && !_first && d.data()['read'] != true && mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
                behavior: SnackBarBehavior.floating, backgroundColor: AppColors.ink,
                content: Text('${d.data()['title']} - ${d.data()['body']}', maxLines: 2, overflow: TextOverflow.ellipsis)));
        }
      }
      _first = false;
    }, onError: (_) {});
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => widget.child;
}
