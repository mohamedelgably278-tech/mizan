import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state.dart' show sb, errMsg;
import 'theme.dart';
import 'widgets.dart';

String rErr(Object e) {
  final m = e is PostgrestException ? e.message : '$e';
  if (m.contains('bad_state')) return 'تغيّرت حالة الطلب، تم التحديث';
  if (m.contains('invalid_code')) return 'كود الشريك غير صحيح';
  return errMsg(e);
}

class RestState extends ChangeNotifier {
  Map<String, dynamic>? profile, rest;
  List<Map<String, dynamic>> orders = [], menu = [];
  bool ready = false;
  RealtimeChannel? _ch;
  Timer? _deb, _alarm, _poll;

  bool get isRest => profile?['role'] == 'restaurant' && profile?['restaurant_id'] != null;
  String? get rid => profile?['restaurant_id'];

  Future<void> init() async {
    sb.auth.onAuthStateChange.listen((d) {
      if (d.event == AuthChangeEvent.signedIn || d.event == AuthChangeEvent.signedOut || d.event == AuthChangeEvent.initialSession) _onSession();
    });
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => load());
    _alarm = Timer.periodic(const Duration(seconds: 5), (_) {
      if (isRest && newOrders.isNotEmpty) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
    });
  }

  Future<void> _onSession() async {
    if (sb.auth.currentSession != null) {
      try {
        profile = Map<String, dynamic>.from(await sb.rpc('dl_ensure_profile', params: {'p_name': null, 'p_phone': null}));
      } catch (_) {}
      await load();
      _subscribe();
    } else {
      profile = rest = null;
      orders = menu = [];
      if (_ch != null) sb.removeChannel(_ch!);
      _ch = null;
    }
    ready = true;
    notifyListeners();
  }

  Future<void> claim(String code) async {
    profile = Map<String, dynamic>.from(await sb.rpc('dl_claim_role', params: {'p_code': code.trim()}));
    await load();
    _subscribe();
    notifyListeners();
  }

  void _subscribe() {
    if (!isRest) return;
    if (_ch != null) sb.removeChannel(_ch!);
    _ch = sb
        .channel('dl-rest')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'dl_orders',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'restaurant_id', value: rid),
            callback: (_) {
              _deb?.cancel();
              _deb = Timer(const Duration(milliseconds: 250), load);
            })
        .subscribe();
  }

  Future<void> load() async {
    if (!isRest) return;
    try {
      final since = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();
      final r = await Future.wait([
        sb.from('dl_orders').select().eq('restaurant_id', rid!).gte('created_at', since).order('created_at', ascending: false).limit(500),
        sb.from('dl_restaurants').select().eq('id', rid!).single(),
        sb.from('dl_menu_items').select().eq('restaurant_id', rid!).order('sort'),
      ]);
      orders = List<Map<String, dynamic>>.from(r[0] as List);
      rest = Map<String, dynamic>.from(r[1] as Map);
      menu = List<Map<String, dynamic>>.from(r[2] as List);
      notifyListeners();
    } catch (_) {}
  }

  List<Map<String, dynamic>> by(String s) => orders.where((o) => o['status'] == s).toList();
  List<Map<String, dynamic>> get newOrders => by('new');

  Future<void> act(int id, String a, [String? arg]) async {
    await sb.rpc('dl_order_action', params: {'p_id': id, 'p_action': a, 'p_arg': arg});
    await load();
  }

  Future<void> setOpen(bool v) async {
    await sb.from('dl_restaurants').update({'open': v}).eq('id', rid!);
    rest?['open'] = v;
    notifyListeners();
  }

  Future<void> setAvailable(String id, bool v) async {
    await sb.from('dl_menu_items').update({'available': v}).eq('id', id);
    menu.firstWhere((m) => m['id'] == id)['available'] = v;
    notifyListeners();
  }

  Future<void> setPrice(String id, double v) async {
    await sb.from('dl_menu_items').update({'price': v}).eq('id', id);
    menu.firstWhere((m) => m['id'] == id)['price'] = v;
    notifyListeners();
  }
}

final rst = RestState();

String ago(dynamic t) {
  final d = DateTime.tryParse('$t');
  if (d == null) return '';
  final m = DateTime.now().difference(d.toLocal()).inMinutes;
  if (m < 1) return 'الآن';
  if (m < 60) return 'منذ $m د';
  return 'منذ ${m ~/ 60} س';
}

/* ====================== HOME ====================== */
class RestHome extends StatefulWidget {
  const RestHome({super.key});
  @override
  State<RestHome> createState() => _RestHomeState();
}

class _RestHomeState extends State<RestHome> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rst,
      builder: (context, _) {
        if (!rst.ready) return const Scaffold(backgroundColor: kV, body: Center(child: CircularProgressIndicator(color: kY)));
        if (sb.auth.currentSession == null) return const RestLogin();
        if (!rst.isRest) return const RestClaim();
        if (rst.rest == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: kO)));
        final open = rst.rest!['open'] == true;
        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: kV,
            foregroundColor: Colors.white,
            titleTextStyle: GoogleFonts.cairo(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
            title: Text('${rst.rest!['name']}'),
            actions: [
              Text(open ? 'مفتوح' : 'مغلق', style: TextStyle(color: open ? kY : Colors.white70, fontWeight: FontWeight.w700)),
              Switch(
                value: open,
                activeTrackColor: kG,
                onChanged: (v) async {
                  try {
                    await rst.setOpen(v);
                  } catch (e) {
                    if (context.mounted) toast(context, rErr(e), error: true);
                  }
                },
              ),
              PopupMenuButton<String>(
                iconColor: Colors.white,
                onSelected: (_) => sb.auth.signOut(),
                itemBuilder: (_) => const [PopupMenuItem(value: 'out', child: Text('تسجيل الخروج'))],
              ),
            ],
          ),
          body: IndexedStack(index: tab, children: const [OrdersBoard(), MenuPage(), ReportsPage()]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: [
              NavigationDestination(
                  icon: Badge(isLabelVisible: rst.newOrders.isNotEmpty, label: Text('${rst.newOrders.length}'), backgroundColor: kO, child: const Icon(Icons.receipt_long_outlined)),
                  selectedIcon: const Icon(Icons.receipt_long, color: kO),
                  label: 'الطلبات'),
              const NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu, color: kO), label: 'المنيو'),
              const NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart, color: kO), label: 'التقارير'),
            ],
          ),
        );
      },
    );
  }
}

/* ====================== ORDERS ====================== */
class OrdersBoard extends StatelessWidget {
  const OrdersBoard({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rst,
      builder: (context, _) {
        final lanes = [
          ('جديد', rst.by('new'), kO, kOl),
          ('قيد التجهيز', rst.by('preparing'), const Color(0xFF946100), kYl),
          ('جاهز للاستلام', rst.by('ready'), kG, kGl),
        ];
        Widget laneList(List<Map<String, dynamic>> l, int i) => l.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(30),
                child: Text(i == 0 ? 'لا طلبات جديدة\nستصلك هنا فورًا مع تنبيه صوتي' : 'لا يوجد', textAlign: TextAlign.center, style: const TextStyle(color: kMu)))
            : Column(children: l.map((o) => OrderCard(o: o)).toList());
        return LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 900) {
            return RefreshIndicator(
              color: kO,
              onRefresh: rst.load,
              child: ListView(padding: const EdgeInsets.all(14), children: [
                _Kpis(),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsetsDirectional.only(end: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLn)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [Expanded(child: Text(lanes[i].$1, style: const TextStyle(fontWeight: FontWeight.w800, color: kV))), Pill('${lanes[i].$2.length}', bg: lanes[i].$4, fg: lanes[i].$3)]),
                          const SizedBox(height: 10),
                          laneList(lanes[i].$2, i),
                        ]),
                      ),
                    ),
                ]),
              ]),
            );
          }
          return DefaultTabController(
            length: 3,
            child: Column(children: [
              Container(
                color: Colors.white,
                child: TabBar(
                  labelColor: kO,
                  unselectedLabelColor: kMu,
                  indicatorColor: kO,
                  labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                  tabs: [for (final l in lanes) Tab(text: '${l.$1} (${l.$2.length})')],
                ),
              ),
              Expanded(
                child: TabBarView(children: [
                  for (var i = 0; i < 3; i++)
                    RefreshIndicator(
                      color: kO,
                      onRefresh: rst.load,
                      child: ListView(padding: const EdgeInsets.all(14), children: [if (i == 0) ...[_Kpis(), const SizedBox(height: 12)], laneList(lanes[i].$2, i)]),
                    ),
                ]),
              ),
            ]),
          );
        });
      },
    );
  }
}

class _Kpis extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = rst.orders.where((o) {
      final t = DateTime.tryParse('${o['created_at']}')?.toLocal();
      return t != null && t.year == now.year && t.month == now.month && t.day == now.day && o['status'] != 'rejected';
    }).toList();
    final sales = today.fold<double>(0, (a, o) => a + n(o['subtotal']));
    final active = rst.orders.where((o) => ['new', 'preparing', 'ready'].contains(o['status'])).length;
    Widget k(String a, String b) => Expanded(
        child: Box(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a, style: const TextStyle(color: kMu, fontSize: 12, fontWeight: FontWeight.w700)),
              Text(b, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kV)),
            ])));
    return Row(children: [k('طلبات اليوم', '${today.length}'), const SizedBox(width: 8), k('مبيعات اليوم', fmt(sales)), const SizedBox(width: 8), k('قيد التنفيذ', '$active')]);
  }
}

class OrderCard extends StatefulWidget {
  final Map<String, dynamic> o;
  const OrderCard({super.key, required this.o});
  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool busy = false;
  Future<void> run(String a, [String? arg]) async {
    setState(() => busy = true);
    try {
      await rst.act(widget.o['id'], a, arg);
      if (mounted) toast(context, {'accept': 'تم قبول الطلب', 'reject': 'تم رفض الطلب', 'ready': 'تم إبلاغ المندوب'}[a]!);
    } catch (e) {
      if (mounted) toast(context, rErr(e), error: true);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> review() async {
    final o = widget.o;
    int prep = 15;
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('طلب جديد #${o['id']}', style: const TextStyle(color: kO, fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final it in (o['items'] as List)) Line('${it['q']}× ${it['name']}', fmt(n(it['q']) * n(it['price']))),
              if ((o['note'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('ملاحظة: ${o['note']}', style: const TextStyle(color: kMu))),
              const Divider(color: kLn),
              Line('المجموع · ${payLabel[o['pay_method']]}', '${fmt(n(o['subtotal']))} $kCur', total: true),
              const SizedBox(height: 12),
              const Text('وقت التجهيز', style: TextStyle(fontWeight: FontWeight.w800, color: kV)),
              const SizedBox(height: 8),
              Wrap(
                  spacing: 8,
                  children: [10, 15, 20, 30]
                      .map((p) => ChoiceChip(
                            label: Text('$p د'),
                            selected: prep == p,
                            showCheckmark: false,
                            selectedColor: kV,
                            labelStyle: TextStyle(color: prep == p ? Colors.white : kV, fontWeight: FontWeight.w800),
                            onSelected: (_) => set(() => prep = p),
                          ))
                      .toList()),
            ]),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'reject'), child: const Text('رفض', style: TextStyle(color: kR, fontWeight: FontWeight.w800))),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(140, 48)), onPressed: () => Navigator.pop(ctx, 'accept:$prep'), child: const Text('قبول الطلب')),
          ],
        ),
      ),
    );
    if (res == null) return;
    if (res == 'reject') {
      await run('reject');
    } else {
      await run('accept', res.split(':')[1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    final st = o['status'];
    final isNew = st == 'new';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNew ? const Color(0xFFFFF8F3) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isNew ? kO : kLn, width: isNew ? 1.5 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('#${o['id']}', style: const TextStyle(fontWeight: FontWeight.w800, color: kV, fontSize: 16))), Text(ago(o['created_at']), style: const TextStyle(color: kMu, fontSize: 12))]),
        const SizedBox(height: 4),
        for (final it in (o['items'] as List)) Text('${it['q']}× ${it['name']}', style: const TextStyle(fontSize: 14)),
        if ((o['note'] ?? '').toString().isNotEmpty) Text('ملاحظة: ${o['note']}', style: const TextStyle(color: kMu, fontSize: 13)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text('${o['customer_name'] ?? ''} · ${payLabel[o['pay_method']]}', style: const TextStyle(color: kMu, fontSize: 13))),
          Text(fmt(n(o['subtotal'])), style: const TextStyle(fontWeight: FontWeight.w800, color: kV)),
        ]),
        if (st == 'preparing' && o['prep_min'] != null) Text('وقت التجهيز: ${o['prep_min']} دقيقة', style: const TextStyle(color: Color(0xFF946100), fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (isNew) FilledButton(onPressed: busy ? null : review, child: const Text('مراجعة وقبول')),
        if (st == 'preparing')
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kGl, foregroundColor: kG), onPressed: busy ? null : () => run('ready'), child: const Text('جاهز للاستلام')),
        if (st == 'ready')
          Row(children: [
            Icon(o['driver_id'] != null ? Icons.two_wheeler : Icons.hourglass_top, size: 18, color: kMu),
            const SizedBox(width: 6),
            Text(o['driver_id'] != null ? 'مندوب في الطريق للمطعم' : 'بانتظار مندوب…', style: const TextStyle(color: kMu)),
          ]),
      ]),
    );
  }
}

/* ====================== MENU ====================== */
class MenuPage extends StatelessWidget {
  const MenuPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rst,
      builder: (context, _) => ListView(padding: const EdgeInsets.all(14), children: [
        const Text('إيقاف صنف يخفيه من تطبيق العميل فورًا. اضغط على السعر لتعديله.', style: TextStyle(color: kMu, fontSize: 13)),
        const SizedBox(height: 10),
        for (final m in rst.menu)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLn)),
            child: Row(children: [
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m['name']}', style: TextStyle(fontWeight: FontWeight.w700, color: m['available'] == true ? kInk : kMu)),
                Text('${m['section']}', style: const TextStyle(color: kMu, fontSize: 12)),
              ])),
              TextButton(
                onPressed: () async {
                  final c = TextEditingController(text: fmt(n(m['price'])));
                  final v = await showDialog<double>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('سعر ${m['name']}'),
                      content: TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), autofocus: true, decoration: const InputDecoration(suffixText: kCur)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(100, 44)), onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.trim())), child: const Text('حفظ')),
                      ],
                    ),
                  );
                  if (v == null || v < 0) return;
                  try {
                    await rst.setPrice(m['id'], v);
                    if (context.mounted) toast(context, 'تم تحديث السعر');
                  } catch (e) {
                    if (context.mounted) toast(context, rErr(e), error: true);
                  }
                },
                child: Text('${fmt(n(m['price']))} $kCur', style: const TextStyle(fontWeight: FontWeight.w800, color: kV)),
              ),
              Switch(
                value: m['available'] == true,
                activeTrackColor: kG,
                onChanged: (v) async {
                  try {
                    await rst.setAvailable(m['id'], v);
                  } catch (e) {
                    if (context.mounted) toast(context, rErr(e), error: true);
                  }
                },
              ),
            ]),
          ),
      ]),
    );
  }
}

/* ====================== REPORTS ====================== */
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: rst,
      builder: (context, _) {
        final now = DateTime.now();
        final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));
        final delivered = rst.orders.where((o) => o['status'] == 'delivered').toList();
        double dayVal(DateTime d) => delivered.where((o) {
              final t = DateTime.tryParse('${o['created_at']}')?.toLocal();
              return t != null && t.year == d.year && t.month == d.month && t.day == d.day;
            }).fold(0.0, (a, o) => a + n(o['subtotal']));
        final vals = days.map(dayVal).toList();
        final tot = vals.fold(0.0, (a, b) => a + b);
        final comm = delivered.fold(0.0, (a, o) => a + n(o['subtotal']) * n(o['commission_pct']) / 100);
        final mx = vals.fold(1.0, (a, b) => b > a ? b : a);
        const wd = ['إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];
        Widget k(String a, String b, [Color c = kV]) => Expanded(
            child: Box(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a, style: const TextStyle(color: kMu, fontSize: 12, fontWeight: FontWeight.w700)),
                  Text(b, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c)),
                ])));
        return ListView(padding: const EdgeInsets.all(14), children: [
          const Text('آخر 7 أيام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kV)),
          const SizedBox(height: 10),
          Row(children: [k('المبيعات المسلّمة', fmt(tot)), const SizedBox(width: 8), k('عمولة المنصة (${fmt(n(rst.rest?['commission']))}٪)', fmt(comm))]),
          const SizedBox(height: 8),
          Row(children: [k('صافي مستحقاتك', fmt(tot - comm), kG), const SizedBox(width: 8), k('طلبات مسلّمة', '${delivered.length}')]),
          const SizedBox(height: 14),
          Box(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('المبيعات اليومية', style: TextStyle(fontWeight: FontWeight.w800, color: kV)),
              const SizedBox(height: 14),
              SizedBox(
                height: 180,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                          if (vals[i] > 0) Text(fmt(vals[i]), style: const TextStyle(fontSize: 10, color: kV, fontWeight: FontWeight.w700)),
                          Container(height: 6 + 130 * vals[i] / mx, decoration: BoxDecoration(color: i == 6 ? kO : kVl, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))),
                          const SizedBox(height: 4),
                          Text(i == 6 ? 'اليوم' : wd[days[i].weekday - 1], style: const TextStyle(fontSize: 10, color: kMu)),
                        ]),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        ]);
      },
    );
  }
}

/* ====================== LOGIN / CLAIM ====================== */
class RestLogin extends StatefulWidget {
  const RestLogin({super.key});
  @override
  State<RestLogin> createState() => _RestLoginState();
}

class _RestLoginState extends State<RestLogin> {
  final email = TextEditingController(), pass = TextEditingController();
  bool busy = false;
  String? err;
  Future<void> go() async {
    setState(() {
      busy = true;
      err = null;
    });
    try {
      await sb.auth.signInWithPassword(email: email.text.trim(), password: pass.text);
    } catch (e) {
      setState(() => err = errMsg(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(22), children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: kO, borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.storefront, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('منصتك — المطاعم', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kV)),
            const Text('استقبل طلباتك وأدر مطعمك', style: TextStyle(color: kMu)),
            const SizedBox(height: 22),
            TextField(controller: email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'البريد الإلكتروني')),
            const SizedBox(height: 10),
            TextField(controller: pass, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'كلمة المرور')),
            if (err != null) Msg(err!),
            const SizedBox(height: 16),
            FilledButton(onPressed: busy ? null : go, child: Text(busy ? 'لحظة…' : 'دخول')),
            const SizedBox(height: 18),
            Box(
              color: kYl,
              border: kYl,
              child: Row(children: [
                const Expanded(child: Text('للعرض: حساب مطعم تجريبي', style: TextStyle(fontWeight: FontWeight.w700, color: kV))),
                TextButton(
                  onPressed: () {
                    email.text = 'restaurant@demo-delivery.app';
                    pass.text = 'Demo@2026';
                    go();
                  },
                  child: const Text('دخول تجريبي', style: TextStyle(color: kO, fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class RestClaim extends StatefulWidget {
  const RestClaim({super.key});
  @override
  State<RestClaim> createState() => _RestClaimState();
}

class _RestClaimState extends State<RestClaim> {
  final code = TextEditingController();
  String? err;
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: [TextButton(onPressed: () => sb.auth.signOut(), child: const Text('خروج'))]),
      body: ListView(padding: const EdgeInsets.all(22), children: [
        const Text('اربط حسابك بمطعمك', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: kV)),
        const Text('أدخل كود المطعم الذي استلمته من إدارة المنصة.', style: TextStyle(color: kMu)),
        const SizedBox(height: 16),
        TextField(controller: code, textDirection: TextDirection.ltr, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'XXXX-XXXXXX')),
        if (err != null) Msg(err!),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    err = null;
                  });
                  try {
                    await rst.claim(code.text);
                    if (!rst.isRest) err = 'هذا الكود ليس كود مطعم';
                  } catch (e) {
                    err = rErr(e);
                  }
                  if (mounted) setState(() => busy = false);
                },
          child: const Text('ربط'),
        ),
      ]),
    );
  }
}
