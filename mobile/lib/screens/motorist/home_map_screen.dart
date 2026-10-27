import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/config.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/session_provider.dart';
import '../../services/geo_service.dart';
import '../../widgets/auto_map.dart';
import '../../widgets/common.dart';
import '../notifications.dart';
import 'recommended_screen.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});
  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  LatLng? _me;
  String _address = 'Locating...';
  bool _gps = false;
  final _map = MapController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _mechs =
      FirebaseFirestore.instance.collection('Mechanics').where('isVerified', isEqualTo: true).snapshots();

  @override
  void initState() { super.initState(); _locate(); }

  Future<void> _locate() async {
    final pos = await GeoService.position();
    final ll = pos == null ? AppConfig.defaultCenter : LatLng(pos.latitude, pos.longitude);
    if (!mounted) return;
    final first = _me == null;
    setState(() { _me = ll; _gps = pos != null; });
    if (!first) { try { _map.move(ll, 15); } catch (_) {} }
    final a = await GeoService.reverse(ll.latitude, ll.longitude);
    if (mounted) setState(() => _address = pos == null ? 'Nairobi (GPS is off)' : a);
  }

  Draft _draft() {
    final v = context.read<SessionProvider>().profile?.vehicle ?? {};
    return Draft(lat: _me!.latitude, lng: _me!.longitude, address: _address,
        make: '${v['make'] ?? ''}', model: '${v['model'] ?? ''}', reg: '${v['reg'] ?? ''}');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final profile = context.watch<SessionProvider>().profile;
    if (_me == null) return const Center(child: CircularProgressIndicator(color: AppColors.orange));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _mechs,
      builder: (context, snap) {
        final nearby = <Mech>[];
        for (final d in snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
          final m = Mech.fromDoc(d.id, d.data());
          if (!m.isAvailable || m.lat == 0 || d.id == profile?.uid) continue;
          final km = const Distance().as(LengthUnit.Kilometer, _me!, m.point);
          if (km <= 15) nearby.add(m);
        }
        return Stack(children: [
          Positioned.fill(child: AutoMap(center: _me!, zoom: 14.5, controller: _map,
              markers: [mePin(_me!), for (final m in nearby) truckPin(m.point)])),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  Avatar(initials(profile?.name ?? '?'), size: 44),
                  const SizedBox(width: 10),
                  Expanded(child: AppCard(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), radius: 14, child: Row(children: [
                    const Icon(Icons.location_on, color: AppColors.orange, size: 18), const SizedBox(width: 6),
                    Expanded(child: Text(_address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    Pill(_gps ? 'GPS Active' : 'GPS off', color: _gps ? AppColors.green : AppColors.amber),
                  ]))),
                  const SizedBox(width: 10),
                  const AppCard(padding: EdgeInsets.zero, radius: 14, child: NotifBell()),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.circle, size: 8, color: AppColors.green), const SizedBox(width: 6),
                    Text('${nearby.length} mechanics nearby', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
            ),
          ),
          Positioned(right: 16, bottom: 292,
              child: AppCard(padding: const EdgeInsets.all(10), radius: 14, onTap: _locate, child: const Icon(Icons.my_location, color: AppColors.orange))),
          Positioned(left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              decoration: BoxDecoration(color: p.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20)]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),
                Row(children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.info, color: AppColors.orange)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Need roadside assistance?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('Find a nearby verified mechanic and get help quickly.', style: TextStyle(color: p.muted, fontSize: 12)),
                  ])),
                ]),
                const SizedBox(height: 14),
                PrimaryButton(label: 'Request a Mechanic', icon: Icons.location_on, onPressed: () => motoristTab.value = 1),
                const SizedBox(height: 10),
                PrimaryButton(label: 'View Nearby Mechanics', outlined: true,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecommendedScreen(draft: _draft())))),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}
