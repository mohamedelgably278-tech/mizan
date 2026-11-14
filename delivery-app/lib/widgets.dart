import 'package:flutter/material.dart';
import 'theme.dart';

class Pill extends StatelessWidget {
  final String text;
  final Color bg, fg;
  const Pill(this.text, {super.key, this.bg = kVl, this.fg = kV});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
      );
}

class Stepper2 extends StatelessWidget {
  final int q;
  final VoidCallback onPlus, onMinus;
  final bool trashAtOne;
  const Stepper2({super.key, required this.q, required this.onPlus, required this.onMinus, this.trashAtOne = false});
  @override
  Widget build(BuildContext context) {
    Widget b(Widget c, VoidCallback f) => InkWell(
          onTap: f,
          borderRadius: BorderRadius.circular(9),
          child: Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)), child: c),
        );
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        b(const Icon(Icons.add, size: 18, color: kO), onPlus),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('$q', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
        b(Icon(trashAtOne && q == 1 ? Icons.delete_outline : Icons.remove, size: 18, color: kO), onMinus),
      ]),
    );
  }
}

class Box extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color, border;
  const Box({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color = Colors.white, this.border = kLn});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18), border: Border.all(color: border)),
        child: child,
      );
}

class Msg extends StatelessWidget {
  final String text;
  final bool ok;
  const Msg(this.text, {super.key, this.ok = false});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: ok ? kGl : kRl, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(color: ok ? kG : kR, fontWeight: FontWeight.w700, fontSize: 13)),
      );
}

class Line extends StatelessWidget {
  final String a, b;
  final bool total;
  final Color? color;
  const Line(this.a, this.b, {super.key, this.total = false, this.color});
  @override
  Widget build(BuildContext context) {
    final st = TextStyle(fontSize: total ? 16 : 14, fontWeight: total ? FontWeight.w800 : FontWeight.w500, color: color ?? (total ? kV : kInk));
    return Padding(
      padding: EdgeInsets.only(top: total ? 10 : 4, bottom: 4),
      child: Row(children: [Expanded(child: Text(a, style: st)), Text(b, style: st)]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const EmptyState(this.icon, this.text, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: const Color(0xFFCFC6DA)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: kMu)),
            if (action != null) ...[
              const SizedBox(height: 16),
              SizedBox(width: 200, child: FilledButton(onPressed: onAction, child: Text(action!))),
            ]
          ]),
        ),
      );
}

void toast(BuildContext context, String m, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), backgroundColor: error ? kR : kV, duration: const Duration(seconds: 2)));
}

(String, Color, Color) statusLabel(String s) => switch (s) {
      'new' => ('بانتظار المطعم', kYl, const Color(0xFF946100)),
      'preparing' => ('يُجهَّز', kOl, kO),
      'ready' => ('جاهز للاستلام', kOl, kO),
      'picked' => ('في الطريق', kVl, kV),
      'delivered' => ('تم التوصيل', kGl, kG),
      'rejected' => ('ملغي', kRl, kR),
      _ => (s, kVl, kV),
    };

const payLabel = {'cash': 'نقدًا', 'card': 'بطاقة', 'wallet': 'محفظة'};
