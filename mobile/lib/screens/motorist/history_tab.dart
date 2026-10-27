import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});
  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  late final Stream<List<ServiceRequest>> _stream = Db.motoristRequests();

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SafeArea(
      child: StreamBuilder<List<ServiceRequest>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return EmptyState(Icons.error_outline, 'Could not load history', '${snap.error}');
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.orange));
          final list = snap.data!.where((r) => r.status == 'paid' || r.status == 'cancelled' || r.status == 'declined').toList();
          final paid = list.where((r) => r.status == 'paid').toList();
          final spent = paid.fold<double>(0, (s, r) => s + r.total);
          return ListView(padding: const EdgeInsets.all(20), children: [
            const Text('Service History', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            Text('${paid.length} past service${paid.length == 1 ? '' : 's'}', style: TextStyle(color: p.muted)),
            const SizedBox(height: 14),
            AppCard(color: p.soft, borderColor: AppColors.orange.withValues(alpha: 0.25), child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.history, color: Colors.white)), const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Total Spent: ${kes(spent)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('Across ${paid.length} service calls', style: TextStyle(color: p.muted, fontSize: 12))])),
            ])),
            const SizedBox(height: 14),
            if (list.isEmpty) const Padding(padding: EdgeInsets.only(top: 40), child: EmptyState(Icons.history, 'No services yet', 'Your completed requests will appear here.')),
            for (final r in list) Padding(padding: const EdgeInsets.only(bottom: 12), child: AppCard(child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Avatar(initials(r.mechanicName), size: 44), const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.mechanicName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(r.category, style: TextStyle(color: p.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(children: [if (r.rating > 0) Stars(r.rating.toDouble(), size: 12), if (r.rating > 0) const SizedBox(width: 6),
                    Text(DateFormat('d MMM yyyy').format(r.createdAt), style: TextStyle(color: p.muted, fontSize: 11.5))]),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Pill(statusLabel(r.status), color: statusColor(r.status)), const SizedBox(height: 6),
                  if (r.status == 'paid') Text(kes(r.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))]),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _details(r), style: OutlinedButton.styleFrom(side: BorderSide(color: p.border), foregroundColor: p.text),
                    child: const Text('View Details', style: TextStyle(fontSize: 12.5)))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: () => motoristTab.value = 1,
                    style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.orange.withValues(alpha: 0.4)), foregroundColor: AppColors.orange),
                    child: const Text('Book Again', style: TextStyle(fontSize: 12.5)))),
              ]),
            ]))),
          ]);
        },
      ),
    );
  }

  void _details(ServiceRequest r) => showModalBottomSheet(
        context: context, showDragHandle: true,
        builder: (_) => Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), child: Column(mainAxisSize: MainAxisSize.min, children: [
          KeyValue('Mechanic', r.mechanicName), KeyValue('Problem', r.category), if (r.description.isNotEmpty) KeyValue('Description', r.description),
          KeyValue('Vehicle', '${r.vehicleLabel} ${r.reg}'.trim().isEmpty ? '-' : '${r.vehicleLabel} ${r.reg}'.trim()),
          KeyValue('Location', r.address.isEmpty ? '-' : r.address), KeyValue('Status', statusLabel(r.status)),
          if (r.status == 'paid') ...[KeyValue('Callout fee', kes(r.n('calloutFee'))), KeyValue('Labour', kes(r.n('labour'))), KeyValue('Parts', kes(r.n('parts'))),
            KeyValue('Total', kes(r.total), bold: true), KeyValue('M-Pesa ref', '${r.d['receipt'] ?? '-'}')],
        ])),
      );
}
