import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

class ReviewScreen extends StatefulWidget {
  final ServiceRequest req;
  const ReviewScreen({super.key, required this.req});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 5;
  final _comment = TextEditingController();
  final _tags = <String>{};
  bool _busy = false;
  static const _all = ['Fast response', 'Professional', 'Friendly', 'Reliable', 'Good service', 'Affordable'];

  @override
  void dispose() { _comment.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ApiService.submitReview(widget.req.id, _rating, _tags.toList(), _comment.text.trim());
      if (!mounted) return;
      showSnack(context, 'Thank you! Your review was submitted.');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal, r = widget.req;
    return Scaffold(
      appBar: AppBar(title: const Text('Rate Your Experience', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        AppCard(child: Row(children: [
          Avatar(initials(r.mechanicName)), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.mechanicName, style: const TextStyle(fontWeight: FontWeight.w700)), Text(r.category, style: TextStyle(color: p.muted, fontSize: 12))])),
        ])),
        const SizedBox(height: 14),
        AppCard(child: Column(children: [
          const Text('How was your experience?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text('Tap a star to rate', style: TextStyle(color: p.muted, fontSize: 12)), const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++) IconButton(iconSize: 40, onPressed: () => setState(() => _rating = i),
                icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: i <= _rating ? AppColors.orange : p.border))]),
          Text.rich(TextSpan(text: '$_rating.0', style: const TextStyle(color: AppColors.orange, fontSize: 30, fontWeight: FontWeight.w800),
              children: [TextSpan(text: ' / 5.0', style: TextStyle(color: p.muted, fontSize: 13, fontWeight: FontWeight.w400))])),
        ])),
        const SizedBox(height: 14),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Quick Tags', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in _all) FilterChip(label: Text(t), selected: _tags.contains(t), showCheckmark: true, checkmarkColor: AppColors.orange,
                selectedColor: AppColors.orange.withValues(alpha: 0.15), side: BorderSide(color: _tags.contains(t) ? AppColors.orange : p.border),
                labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _tags.contains(t) ? AppColors.orange : p.muted),
                onSelected: (v) => setState(() => v ? _tags.add(t) : _tags.remove(t))),
          ]),
        ])),
        const SizedBox(height: 14),
        AppCard(child: LabeledField(label: 'Tell us about your experience', controller: _comment, maxLines: 4, hint: 'e.g. He arrived quickly and had the right battery in stock...')),
        const SizedBox(height: 18),
        PrimaryButton(label: 'Submit Review', loading: _busy, onPressed: _submit),
        const SizedBox(height: 8),
        Center(child: Text('Your feedback helps other motorists choose reliable mechanics.', style: TextStyle(color: p.muted, fontSize: 11.5), textAlign: TextAlign.center)),
      ]),
    );
  }
}
