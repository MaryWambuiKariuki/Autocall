import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/session_provider.dart';
import 'admin/admin_shell.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'mechanic/mechanic_shell.dart';
import 'motorist/motorist_shell.dart';
import 'notifications.dart';

/// Decides what to show: login -> (complete profile) -> role-specific home.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SessionProvider>();
    if (!s.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.orange)));
    }
    if (s.user == null) return const LoginScreen();
    final p = s.profile;
    if (p == null) return const RegisterScreen(completeMode: true);
    switch (p.role) {
      case 'mechanic': return const NotifyHost(child: MechanicShell());
      case 'admin': return const AdminShell();
      default: return const NotifyHost(child: MotoristShell());
    }
  }
}
