import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/request_flow.dart';
import '../../widgets/common.dart';
import 'mechanic_profile_screen.dart';

class RecommendedScreen extends StatefulWidget {
  final Draft draft;
  const RecommendedScreen({super.key, required this.draft});
  @override
  State<RecommendedScreen> createState() => _RecommendedScreenState();
}

class _RecommendedScreenState extends State<RecommendedScreen> {
  List<Mech>? _all;
  String? _error;
  String _filter = 'Best Match';
  bool _busy = false;
  static const _filters = ['Best Match', 'Nearest', 'Top Rated', 'Fastest'];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _all = null; _error = null; });
    try {
      final l = await ApiService.recommend(widget.draft);
      if (l.isNotEmpty) {
        final maxR = l.map((m) => m.rating).reduce(max);
        final minE = l.map((m) => m.etaMin).reduce(min);
        final minD = l.map((m) => m.distanceKm).reduce(min);
        for (var i = 0; i < l.length; i++) {
          final m = l[i];
          m.badge = i == 0 ? 'Best Match' : (m.rating == maxR && m.reviewCount > 0) ? 'Top Rated'
              : m.etaMin == minE ? 'Fastest ETA' : m.distanceKm == minD ? 'Nearest' : null;
        }
      }
      if (mounted) setState(() => _all = l);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  List<Mech> get _sorted {
    final l = [..._all!];
    switch (_filter) {
      case 'Nearest': l.sort((a, b) => a.distanceKm.compareTo(b.distanceKm)); break;
      case 'Top Rated': l.sort((a, b) => b.rating.compareTo(a.rating)); break;
      case 'Fastest': l.sort((a, b) => a.etaMin.compareTo(b.etaMin)); break;
      default: l.sort((a, b) => b.score.compareTo(a.score));
    }
    return l;
  }

  Future<void> _request(Mech m) async {
    setState(() => _busy = true);
    await sendRequest(context, widget.draft, m);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      appBar: AppBar(title: const Text('Recommended Mechanics', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
      body: _error != null
          ? Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              ErrorBox(_error!), const SizedBox(height: 16), PrimaryButton(label: 'Try again', onPressed: _load)]))
          : _all == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
              : Column(children: [
                  Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Align(alignment: Alignment.centerLeft,
                      child: Text('Ranked by distance, rating, availability & response time', style: TextStyle(color: p.muted, fontSize: 12)))),
                  SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                    for (final f in _filters)
                      Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                        label: Text(f), selected: _filter == f, showCheckmark: false, selectedColor: AppColors.orange,
                        labelStyle: TextStyle(color: _filter == f ? Colors.white : p.text, fontWeight: FontWeight.w600, fontSize: 12.5),
                        side: BorderSide(color: _filter == f ? AppColors.orange : p.border), onSelected: (_) => setState(() => _filter = f))),
                  ])),
                  Expanded(
                    child: _all!.isEmpty
                        ? const EmptyState(Icons.search_off, 'No verified mechanics available nearby',
                            'None are online within 30 km. Run the seed script around your location, or have a mechanic account go online.')
                        : ListView(padding: const EdgeInsets.all(16), children: [
                            for (var i = 0; i < _sorted.length; i++) _card(_sorted[i], i),
                          ]),
                  ),
                ]),
    );
  }

  Widget _card(Mech m, int i) {
    final p = context.pal;
    final colors = [AppColors.orange, AppColors.ink, AppColors.green];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        borderColor: i == 0 && _filter == 'Best Match' ? AppColors.orange.withValues(alpha: 0.5) : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Avatar(initials(m.name), size: 48, color: colors[i % 3]),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              const Pill('Verified', color: AppColors.green, icon: Icons.verified),
              const SizedBox(height: 4),
              Row(children: [
                Stars(m.rating, size: 13), const SizedBox(width: 6),
                Text(m.reviewCount == 0 ? 'New' : '${m.rating.toStringAsFixed(1)} (${m.reviewCount})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              Text(m.spec, style: TextStyle(color: p.muted, fontSize: 12)),
            ])),
            if (m.badge != null) Pill(m.badge!, color: m.badge == 'Best Match' ? AppColors.orange : AppColors.blue),
          ]),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: p.field, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              _stat('away', '${m.distanceKm.toStringAsFixed(1)} km'), _stat('ETA', '${m.etaMin} min'), _stat('est. fee', kes(m.estFee)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(flex: 2, child: PrimaryButton(label: 'Profile', outlined: true,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MechanicProfileScreen(mech: m, draft: widget.draft))))),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: PrimaryButton(label: 'Request', loading: _busy, onPressed: () => _request(m))),
          ]),
        ]),
      ),
    );
  }

  Widget _stat(String k, String v) => Expanded(child: Column(children: [
        Text(k, style: TextStyle(color: context.pal.muted, fontSize: 10.5)), const SizedBox(height: 2),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ]));
}
