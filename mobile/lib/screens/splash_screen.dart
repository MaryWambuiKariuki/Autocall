import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(color: AppColors.orange, borderRadius: BorderRadius.circular(28), boxShadow: [
                BoxShadow(color: AppColors.orange.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 10))]),
              child: const Icon(Icons.location_on, color: Colors.white, size: 52),
            ),
            const SizedBox(height: 22),
            const Text('Autocall', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Roadside Help, When You Need It', style: TextStyle(color: p.muted, fontSize: 13)),
            const SizedBox(height: 36),
            Container(
              width: 210, height: 110,
              decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.orange.withValues(alpha: 0.2))),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.directions_car_filled, size: 46, color: Colors.grey),
                SizedBox(width: 14),
                Icon(Icons.build_circle, size: 46, color: AppColors.orange),
              ]),
            ),
            const SizedBox(height: 40),
            const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.orange)),
            const SizedBox(height: 12),
            Text('Connecting to nearby mechanics...', style: TextStyle(color: p.muted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
