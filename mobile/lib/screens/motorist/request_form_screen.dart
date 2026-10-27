import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/session_provider.dart';
import '../../services/db.dart';
import '../../services/geo_service.dart';
import '../../widgets/auto_map.dart';
import '../../widgets/common.dart';
import 'recommended_screen.dart';
import 'track_screen.dart';

/// "Requests" tab: shows the live request if one exists, otherwise the problem form.
class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});
  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  late final Stream<List<ServiceRequest>> _stream = Db.motoristRequests();
  @override
  Widget build(BuildContext context) => StreamBuilder<List<ServiceRequest>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return EmptyState(Icons.error_outline, 'Could not load requests', '${snap.error}');
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.orange));
          final active = snap.data!.where((r) => r.activeForMotorist).toList();
          if (active.isEmpty) return const RequestFormScreen();
          return TrackScreen(key: ValueKey(active.first.id), req: active.first);
        },
      );
}

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});
  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  static const _cats = <List<Object>>[
    ['Engine', Icons.build], ['Battery', Icons.battery_charging_full], ['Tyre', Icons.tire_repair],
    ['Electrical', Icons.bolt], ['Brakes', Icons.stop_circle], ['Fuel', Icons.local_gas_station], ['Other', Icons.help_outline]];
  String _cat = 'Battery';
  final _desc = TextEditingController(), _make = TextEditingController(), _model = TextEditingController(), _reg = TextEditingController();
  LatLng? _me;
  String _address = 'Locating...';
  bool _gps = false;

  @override
  void initState() {
    super.initState();
    final v = context.read<SessionProvider>().profile?.vehicle ?? {};
    _make.text = '${v['make'] ?? ''}'; _model.text = '${v['model'] ?? ''}'; _reg.text = '${v['reg'] ?? ''}';
    _locate();
  }

  @override
  void dispose() { _desc.dispose(); _make.dispose(); _model.dispose(); _reg.dispose(); super.dispose(); }

  Future<void> _locate() async {
    final pos = await GeoService.position();
    final ll = pos == null ? AppConfig.defaultCenter : LatLng(pos.latitude, pos.longitude);
    if (!mounted) return;
    setState(() { _me = ll; _gps = pos != null; });
    final a = await GeoService.reverse(ll.latitude, ll.longitude);
    if (mounted) setState(() => _address = pos == null ? 'Nairobi (GPS is off)' : a);
  }

  void _find() {
    if (_me == null) return;
    if (!_gps) showSnack(context, 'GPS is off or permission denied - using Nairobi CBD as your location.', error: true);
    final d = Draft(category: _cat, description: _desc.text.trim(), make: _make.text.trim(), model: _model.text.trim(),
        reg: _reg.text.trim().toUpperCase(), address: _address, lat: _me!.latitude, lng: _me!.longitude);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecommendedScreen(draft: d)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
          const Text("What's wrong with\nyour vehicle?", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15)),
          const SizedBox(height: 18),
          const Text('Problem Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final c in _cats)
              SizedBox(width: 76, child: AppCard(
                padding: const EdgeInsets.symmetric(vertical: 12), radius: 14,
                borderColor: _cat == c[0] ? AppColors.orange : null, color: _cat == c[0] ? p.soft : null,
                onTap: () => setState(() => _cat = c[0] as String),
                child: Column(children: [
                  Icon(c[1] as IconData, color: _cat == c[0] ? AppColors.orange : p.muted),
                  const SizedBox(height: 4),
                  Text(c[0] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _cat == c[0] ? AppColors.orange : p.muted)),
                ]),
              )),
          ]),
          const SizedBox(height: 18),
          LabeledField(label: 'Problem Description', controller: _desc, maxLines: 3, hint: "e.g. My battery seems dead, car won't start and lights are dim..."),
          const SizedBox(height: 18),
          const Text('Your Location', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          AppCard(padding: const EdgeInsets.all(12), child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.location_on, color: AppColors.orange)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Current Location', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('$_address - ${_gps ? 'GPS Active' : 'GPS off'}', style: TextStyle(color: p.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            Icon(Icons.circle, size: 10, color: _gps ? AppColors.green : AppColors.amber),
          ])),
          const SizedBox(height: 10),
          if (_me != null)
            ClipRRect(borderRadius: BorderRadius.circular(16),
                child: SizedBox(height: 130, child: AutoMap(center: _me!, zoom: 15, interactive: false, markers: [mePin(_me!)]))),
          const SizedBox(height: 18),
          Row(children: [Expanded(child: Divider(color: p.border)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('VEHICLE INFO', style: TextStyle(color: p.muted, fontSize: 10.5, fontWeight: FontWeight.w700))),
            Expanded(child: Divider(color: p.border))]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: LabeledField(label: 'Make', controller: _make, hint: 'Toyota')), const SizedBox(width: 12),
            Expanded(child: LabeledField(label: 'Model', controller: _model, hint: 'Fielder'))]),
          const SizedBox(height: 12),
          LabeledField(label: 'Reg. Number', controller: _reg, hint: 'KCA 123A'),
          const SizedBox(height: 22),
          PrimaryButton(label: 'Find a Mechanic', icon: Icons.location_on, onPressed: _me == null ? null : _find),
        ]),
      ),
    );
  }
}
