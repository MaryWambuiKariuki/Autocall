import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/session_provider.dart';
import '../widgets/common.dart';

/// Shared by motorist, mechanic and admin shells. Contains the Light / Dark theme switch.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final u = context.watch<SessionProvider>().profile;
    if (u == null) return const SizedBox.shrink();
    final v = u.vehicle;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Profile', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        AppCard(child: Row(children: [
          Avatar(initials(u.name), size: 60), const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Pill(u.role[0].toUpperCase() + u.role.substring(1), color: AppColors.orange),
          ])),
        ])),
        const SizedBox(height: 12),
        AppCard(child: Column(children: [
          KeyValue('Email', u.email.isEmpty ? '-' : u.email), KeyValue('Phone', u.phone.isEmpty ? '-' : u.phone),
          if (u.role == 'motorist') KeyValue('Vehicle', '${v['make'] ?? ''} ${v['model'] ?? ''} ${v['reg'] ?? ''}'.trim().isEmpty ? '-' : '${v['make'] ?? ''} ${v['model'] ?? ''} ${v['reg'] ?? ''}'.trim()),
        ])),
        const SectionTitle('Appearance'),
        const AppCard(child: SizedBox(width: double.infinity, child: ThemeSelector())),
        const SizedBox(height: 22),
        PrimaryButton(label: 'Sign out', icon: Icons.logout, outlined: true, color: AppColors.red, onPressed: () => context.read<SessionProvider>().signOut()),
        const SizedBox(height: 16),
        Center(child: Text('Autocall v1.0.0', style: TextStyle(color: p.muted, fontSize: 11))),
      ]),
    );
  }
}
