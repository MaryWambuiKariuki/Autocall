import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/request_flow.dart';
import '../../widgets/common.dart';

class MechanicProfileScreen extends StatefulWidget {
  final Mech mech;
  final Draft draft;
  const MechanicProfileScreen({super.key, required this.mech, required this.draft});
  @override
  State<MechanicProfileScreen> createState() => _MechanicProfileScreenState();
}

class _MechanicProfileScreenState extends State<MechanicProfileScreen> {
  bool _busy = false;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _reviews =
      FirebaseFirestore.instance.collection('Reviews').where('mechanicId', isEqualTo: widget.mech.id).snapshots();

  @override
  Widget build(BuildContext context) {
    final p = context.pal, m = widget.mech;
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        Container(
          color: p.soft,
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 8, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconButton(style: IconButton.styleFrom(backgroundColor: p.card), icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
            const SizedBox(height: 8),
            Row(children: [
              Avatar(initials(m.name), size: 76),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Wrap(spacing: 6, children: [Pill('Verified', color: AppColors.green, icon: Icons.verified), Pill('Available', color: AppColors.green)]),
                const SizedBox(height: 6),
                Row(children: [Stars(m.rating), const SizedBox(width: 6),
                  Text(m.reviewCount == 0 ? 'New on Autocall' : '${m.rating.toStringAsFixed(1)} (${m.reviewCount} reviews)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))]),
              ])),
            ]),
          ]),
        ),
        Container(
          color: p.card, padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            _s('${m.completedJobs}', 'Jobs Done'), _s('${m.experienceYears} yrs', 'Experience'),
            _s('${m.distanceKm.toStringAsFixed(1)} km', 'Distance'), _s('${m.etaMin} min', 'ETA'),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Specializations', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in (m.specializations.isEmpty ? ['General Mechanic'] : m.specializations))
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.orange.withValues(alpha: 0.3))),
                      child: Text(s, style: const TextStyle(color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
            ])),
            const SizedBox(height: 14),
            AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Recent Reviews', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _reviews,
                builder: (c, s) {
                  final docs = (s.data?.docs ?? []).map((d) => d.data()).toList();
                  int ms(Map<String, dynamic> r) => (r['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                  docs.sort((a, b) => ms(b).compareTo(ms(a)));
                  if (docs.isEmpty) return Padding(padding: const EdgeInsets.only(top: 10), child: Text('No reviews yet.', style: TextStyle(color: p.muted)));
                  return Column(children: [
                    for (final r in docs.take(4)) Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('${r['motoristName'] ?? 'Motorist'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                          Stars((r['rating'] as num?)?.toDouble() ?? 0, size: 12), const SizedBox(width: 6),
                          Text(timeAgo((r['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()), style: TextStyle(color: p.muted, fontSize: 11)),
                        ]),
                        if ('${r['comment'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${r['comment']}', style: TextStyle(color: p.muted, fontSize: 12.5))),
                      ]),
                    ),
                  ]);
                },
              ),
            ])),
            const SizedBox(height: 18),
            PrimaryButton(label: 'Request This Mechanic', loading: _busy, onPressed: () async {
              setState(() => _busy = true);
              await sendRequest(context, widget.draft, m);
              if (mounted) setState(() => _busy = false);
            }),
          ]),
        ),
      ]),
    );
  }

  Widget _s(String v, String k) => Expanded(child: Column(children: [
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 2),
        Text(k, style: TextStyle(color: context.pal.muted, fontSize: 11)),
      ]));
}
