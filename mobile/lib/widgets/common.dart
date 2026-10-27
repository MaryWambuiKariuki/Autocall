import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/theme_provider.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color, borderColor;
  final double radius;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap,
      this.color, this.borderColor, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      decoration: BoxDecoration(
        color: color ?? p.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? p.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
            borderRadius: BorderRadius.circular(radius), onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading, outlined;
  final Color? color;
  const PrimaryButton({super.key, required this.label, this.onPressed, this.icon, this.loading = false,
      this.outlined = false, this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final bg = color ?? AppColors.orange;
    final inner = loading
        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: outlined ? bg : Colors.white))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
          ]);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return SizedBox(
      width: double.infinity, height: 52,
      child: outlined
          ? OutlinedButton(onPressed: loading ? null : onPressed,
              style: OutlinedButton.styleFrom(foregroundColor: color ?? p.text, side: BorderSide(color: color ?? p.border), shape: shape),
              child: inner)
          : ElevatedButton(onPressed: loading ? null : onPressed,
              style: ElevatedButton.styleFrom(backgroundColor: bg, foregroundColor: Colors.white, elevation: 0,
                  shadowColor: bg.withValues(alpha: 0.4), shape: shape),
              child: inner),
    );
  }
}

class LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint, helper;
  final bool obscure, enabled;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  const LabeledField({super.key, required this.label, this.controller, this.hint, this.helper, this.obscure = false,
      this.enabled = true, this.keyboard, this.validator, this.suffix, this.maxLines = 1, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    OutlineInputBorder b(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller, obscureText: obscure, keyboardType: keyboard, validator: validator,
        maxLines: obscure ? 1 : maxLines, enabled: enabled, onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint, helperText: helper, filled: true, fillColor: p.field, suffixIcon: suffix,
          hintStyle: TextStyle(color: p.muted.withValues(alpha: 0.8), fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: b(p.border), enabledBorder: b(p.border), focusedBorder: b(AppColors.orange, 1.6),
          errorBorder: b(AppColors.red), focusedErrorBorder: b(AppColors.red, 1.6),
        ),
      ),
    ]);
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Pill(this.text, {super.key, required this.color, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      );
}

class Avatar extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  const Avatar(this.text, {super.key, this.size = 48, this.color});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color ?? AppColors.orange, borderRadius: BorderRadius.circular(size * 0.3)),
        alignment: Alignment.center,
        child: Text(text, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.34)),
      );
}

class Stars extends StatelessWidget {
  final double rating;
  final double size;
  const Stars(this.rating, {super.key, this.size = 14});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(i <= rating.round() ? Icons.star_rounded : Icons.star_outline_rounded, size: size,
              color: i <= rating.round() ? AppColors.orange : context.pal.border),
      ]);
}

class ErrorBox extends StatelessWidget {
  final String message;
  const ErrorBox(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.red.withValues(alpha: 0.35))),
        child: Row(children: [
          const Icon(Icons.error, color: AppColors.red, size: 18), const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.red, fontSize: 12.5))),
        ]),
      );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(color: AppColors.orange, fontSize: 12.5))),
        ]),
      );
}

class KeyValue extends StatelessWidget {
  final String k, v;
  final bool bold;
  const KeyValue(this.k, this.v, {super.key, this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: TextStyle(color: context.pal.muted, fontSize: 13)),
          const SizedBox(width: 12),
          Flexible(child: Text(v, textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const EmptyState(this.icon, this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: context.pal.muted), const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: context.pal.muted, fontSize: 13), textAlign: TextAlign.center),
          ]),
        ),
      );
}

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? AppColors.red : AppColors.ink,
        behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
}

/// Light / Dark / System switch used on every Profile screen.
class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>();
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined, size: 18), label: Text('Light')),
        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined, size: 18), label: Text('Dark')),
        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android, size: 18), label: Text('System')),
      ],
      selected: {t.mode},
      onSelectionChanged: (s) => t.set(s.first),
    );
  }
}
