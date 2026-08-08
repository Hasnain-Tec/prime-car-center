import 'package:flutter/material.dart';
import '../core/theme.dart';

class PccPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final EdgeInsets padding;
  const PccPanel({super.key, required this.title, required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: padding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 4, height: 20, decoration: BoxDecoration(color: PccColors.hazard, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Expanded(child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: .4))),
            ]),
            const SizedBox(height: 18),
            child,
          ]),
        ),
      );
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const MetricCard({super.key, required this.label, required this.value, this.accent = PccColors.hazard});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: PccColors.charcoal, borderRadius: BorderRadius.circular(9), border: Border(bottom: BorderSide(color: accent, width: 3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: const TextStyle(color: Color(0xFFAAB4BF), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .5)),
          const SizedBox(height: 7),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        ]),
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()), backgroundColor: PccColors.danger));
}

void showSuccess(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: PccColors.success));
}

String money(double value, [String currency = 'AED']) => '$currency ${value.toStringAsFixed(2)}';

Future<bool> confirmAction(BuildContext context, String message) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm action'),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
          ],
        ),
      ) ??
      false;
}
