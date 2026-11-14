import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'state.dart' show sb, errMsg;
import 'theme.dart';
import 'widgets.dart';

const _dErr = {
  'taken': 'أخذ مندوب آخر هذا الطلب',
  'busy': 'أكمل طلبك الحالي أولًا',
  'not_ready': 'الطلب لم يجهز بعد',
  'bad_code': 'كود التسليم غير صحيح',
  'bad_state': 'تغيّرت حالة الطلب، تم التحديث',
  'invalid_code': 'كود الشريك غير صحيح',
};
String dErr(Object e) {
  final m = e is PostgrestException ? e.message : '$e';
  for (final k in _dErr.keys) {
    if (m.contains(k)) return _dErr[k]!;
  }
  return errMsg(e);
}

class DriverState extends ChangeNotifier {
  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> orders = [];
  Map<String, String> restNames = {};
  double earn = 0;
  int trips = 0;
  bool online = true, ready = false;
  final _known = <int>{};
  bool _first = true;
  RealtimeChannel? _ch;
  Timer? _deb, _poll;

  String? get uid => sb.auth.currentUser?.id;
  bool get isDriver => profile?['role'] == 'driver';

  Future<void> init() async {
    sb.auth.onAuthStateChange.listen((d) {
      if (d.event == AuthChangeEvent.signedIn || d.event == AuthChangeEvent.signedOut || d.event == AuthChangeEvent.initialSession) _onSession();
    });
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => load());
  }

  Future<void> _onSession() async {
    _known.clear();
    _first = true;
    if (sb.auth.currentSession != null) {
      try {
        profile = Map<String, dynamic>.from(await sb.rpc('dl_ensure_profile', params: {'p_name': null, 'p_phone': null}));
        final r = await sb.from('dl_restaurants').select('id,name');
        restNames = {for (final x in r) x['id'] as String: x['name'] as String};
      } catch (_) {}
      await load();
      _subscribe();
    } else {
      profile = null;
      orders = [];
      if (_ch != null) sb.removeChannel(_ch!);
      _ch = null;
    }
    ready = true;
    notifyListeners();
  }

  Future<void> claim(String code) async {
    profile = Map<String, dynamic>.from(await sb.rpc('dl_claim_role', params: {'p_code': code.trim()}));
    _first = true;
    await load();
    _subscribe();
    notifyListeners();
  }

  void _subscribe() {
    if (_ch != null) sb.removeChannel(_ch!);
    _ch = sb.channel('dl-driver').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'dl_orders', callback: (_) {
      _deb?.cancel();
      _deb = Timer(const Duration(milliseconds: 250), load);
    }).subscribe();
  }

  Future<void> load() async {
    if (!isDriver) return;
    try {
      final d = await sb.from('dl_orders').select().or('driver_id.eq.$uid,driver_id.is.null').inFilter('status', ['preparing', 'ready', 'picked', 'delivered']).order('created_at', ascending: false).limit(100);
      final list = List<Map<String, dynamic>>.from(d);
      final fresh = list.where((o) => o['driver_id'] == null && !_known.contains(o['id'])).toList();
      if (!_first && fresh.isNotEmpty && online && job == null) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      }
      _known.addAll(list.map((o) => o['id'] as int));
      _first = false;
      orders = list;
      final s = await sb.rpc('dl_driver_stats');
      earn = n(s['earn']);
      trips = (s['trips'] as num).toInt();
      notifyListeners();
    } catch (_) {}
  }

  Map<String, dynamic>? get job {
    for (final o in orders) {
      if (o['driver_id'] == uid && ['preparing', 'ready', 'picked'].contains(o['status'])) return o;
    }
    return null;
  }

  List<Map<String, dynamic>> get offers => orders.where((o) => o['driver_id'] == null && ['preparing', 'ready'].contains(o['status'])).toList();
  List<Map<String, dynamic>> get doneToday {
    final now = DateTime.now();
    return orders.where((o) {
      final t = DateTime.tryParse('${o['created_at']}')?.toLocal();
      return o['driver_id'] == uid && o['status'] == 'delivered' && t != null && t.year == now.year && t.month == now.month && t.day == now.day;
    }).toList();
  }

  Future<void> act(int id, String action, [String? arg]) async {
    await sb.rpc('dl_order_action', params: {'p_id': id, 'p_action': action, 'p_arg': arg});
    await load();
  }

  void toggleOnline() {
    online = !online;
    notifyListeners();
  }
}

final drv = DriverState();

double fee(Map<String, dynamic> o) => (12 + n(o['total']) * 0.05).roundToDouble();

Future<void> openMap(String q) async {
  final u = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}');
  await launchUrl(u, mode: LaunchMode.externalApplication);
}

Future<void> callPhone(String p) async {
  await launchUrl(Uri.parse('tel:+966$p'));
}

/* ====================== APP ====================== */
class DriverHome extends StatelessWidget {
  const DriverHome({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: drv,
      builder: (context, _) {
        if (!drv.ready) return const Scaffold(backgroundColor: kV, body: Center(child: CircularProgressIndicator(color: kY)));
        if (sb.auth.currentSession == null) return const DriverLogin();
        if (!drv.isDriver) return const ClaimScreen();
        final job = drv.job;
        return Scaffold(
          backgroundColor: kBg,
          body: RefreshIndicator(
            color: kO,
            onRefresh: drv.load,
            child: ListView(padding: EdgeInsets.zero, children: [
              Container(
                padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 14, 18, 22),
                decoration: const BoxDecoration(color: kV, borderRadius: BorderRadius.vertical(bottom: Radius.circular(26))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('أهلًا ${drv.profile?['name'] ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 13))),
                    Text(drv.online ? 'متصل' : 'غير متصل', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Switch(value: drv.online, onChanged: job != null ? null : (_) => drv.toggleOnline(), activeTrackColor: kG, activeColor: Colors.white),
                  ]),
                  const Text('أرباح اليوم', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Text('${fmt(drv.earn)} $kCur', style: const TextStyle(color: kY, fontSize: 36, fontWeight: FontWeight.w800)),
                  Text('${drv.trips} توصيلات مكتملة اليوم', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
              if (job != null)
                JobCard(o: job)
              else if (!drv.online)
                const EmptyState(Icons.bedtime_outlined, 'أنت غير متصل\nاتصل لتبدأ استقبال الطلبات')
              else if (drv.offers.isEmpty)
                const EmptyState(Icons.radar, 'بانتظار طلبات قريبة منك…\nسيصلك تنبيه فور وجود طلب')
              else
                ...drv.offers.map((o) => OfferCard(o: o)),
              if (drv.doneToday.isNotEmpty) ...[
                const Padding(padding: EdgeInsets.fromLTRB(18, 18, 18, 6), child: Text('توصيلات اليوم', style: TextStyle(fontWeight: FontWeight.w800, color: kV, fontSize: 16))),
                ...drv.doneToday.map((o) => Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                      child: Box(
                          child: Row(children: [
                        const Icon(Icons.check_circle, color: kG),
                        const SizedBox(width: 10),
                        Expanded(child: Text('#${o['id']} · ${drv.restNames[o['restaurant_id']] ?? ''}')),
                        Text('+${fmt(fee(o))} $kCur', style: const TextStyle(fontWeight: FontWeight.w800, color: kG)),
                      ])),
                    )),
              ],
              Padding(
                padding: const EdgeInsets.all(18),
                child: TextButton.icon(onPressed: () => sb.auth.signOut(), icon: const Icon(Icons.logout, color: kMu), label: const Text('تسجيل الخروج', style: TextStyle(color: kMu))),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class OfferCard extends StatefulWidget {
  final Map<String, dynamic> o;
  const OfferCard({super.key, required this.o});
  @override
  State<OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<OfferCard> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: kO, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('طلب توصيل #${o['id']}', style: const TextStyle(color: kO, fontWeight: FontWeight.w800, fontSize: 17))),
          Pill('+${fmt(fee(o))} $kCur', bg: kGl, fg: kG),
        ]),
        const SizedBox(height: 10),
        _Route(from: drv.restNames[o['restaurant_id']] ?? '', fromSub: o['status'] == 'ready' ? 'جاهز للاستلام' : 'يُجهَّز الآن', to: '${o['address'] ?? '—'}', toSub: '${(o['items'] as List).length} أصناف · ${o['pay_method'] == 'cash' ? 'تحصيل ${fmt(n(o['total']))} $kCur' : 'مدفوع مسبقًا'}'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    await drv.act(o['id'], 'take');
                    if (context.mounted) toast(context, 'الطلب لك، توجّه للمطعم');
                  } catch (e) {
                    if (context.mounted) toast(context, dErr(e), error: true);
                  }
                  if (mounted) setState(() => busy = false);
                },
          child: Text(busy ? 'لحظة…' : 'قبول الطلب'),
        ),
      ]),
    );
  }
}

class _Route extends StatelessWidget {
  final String from, fromSub, to, toSub;
  const _Route({required this.from, required this.fromSub, required this.to, required this.toSub});
  @override
  Widget build(BuildContext context) {
    Widget pt(Color c, String a, String b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 12, color: c)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a, style: const TextStyle(fontWeight: FontWeight.w800)), Text(b, style: const TextStyle(color: kMu, fontSize: 13))])),
        ]);
    return Column(children: [pt(kO, from, fromSub), const SizedBox(height: 10), pt(kV, to, toSub)]);
  }
}

class JobCard extends StatefulWidget {
  final Map<String, dynamic> o;
  const JobCard({super.key, required this.o});
  @override
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {
  bool busy = false;
  String? err;
  final code = TextEditingController();

  Future<void> run(String a, [String? arg]) async {
    setState(() {
      busy = true;
      err = null;
    });
    try {
      await drv.act(widget.o['id'], a, arg);
      if (a == 'deliver' && mounted) toast(context, 'تم التسليم بنجاح');
    } catch (e) {
      if (a == 'deliver') {
        err = dErr(e);
      } else if (mounted) {
        toast(context, dErr(e), error: true);
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    final st = o['status'] as String;
    final stage = st == 'picked' ? (o['driver_stage'] as int? ?? 1) : 0;
    const labels = ['متجه للمطعم', 'استلمت الطلب', 'في الطريق للعميل', 'عند العميل'];
    final rName = drv.restNames[o['restaurant_id']] ?? '';
    final phone = o['customer_phone'] as String?;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Box(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text('طلب #${o['id']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kV))), Pill(labels[stage], bg: kOl, fg: kO)]),
          const SizedBox(height: 10),
          Row(children: List.generate(4, (i) => Expanded(child: Container(height: 5, margin: const EdgeInsetsDirectional.only(end: 6), decoration: BoxDecoration(color: i <= stage ? kO : kLn, borderRadius: BorderRadius.circular(4)))))),
          const SizedBox(height: 14),
          _Route(from: rName, fromSub: 'الاستلام', to: '${o['address'] ?? '—'}', toSub: 'التسليم · ${o['customer_name'] ?? ''}${(o['note'] ?? '').toString().isNotEmpty ? ' · ${o['note']}' : ''}'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => openMap(stage == 0 ? rName : '${o['address']}'),
                icon: const Icon(Icons.navigation_outlined),
                label: Text(stage == 0 ? 'الطريق للمطعم' : 'الطريق للعميل'),
                style: OutlinedButton.styleFrom(foregroundColor: kV, minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            if (phone != null && phone.isNotEmpty) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => callPhone(phone),
                icon: const Icon(Icons.call_outlined),
                label: const Text('اتصال'),
                style: OutlinedButton.styleFrom(foregroundColor: kV, minimumSize: const Size(0, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              for (final it in (o['items'] as List)) Line('${it['q']}× ${it['name']}', ''),
              const Divider(color: kLn),
              Line(o['pay_method'] == 'cash' ? 'حصّل من العميل' : 'مدفوع مسبقًا', o['pay_method'] == 'cash' ? '${fmt(n(o['total']))} $kCur' : '✓', total: true),
            ]),
          ),
          const SizedBox(height: 14),
          if (stage == 0)
            st == 'ready'
                ? FilledButton(onPressed: busy ? null : () => run('pickup'), child: const Text('وصلت واستلمت الطلب'))
                : const FilledButton(onPressed: null, child: Text('المطعم يجهّز الطلب…')),
          if (stage == 1) FilledButton(onPressed: busy ? null : () => run('depart'), child: const Text('ابدأ التوصيل للعميل')),
          if (stage == 2) FilledButton(onPressed: busy ? null : () => run('arrive'), child: const Text('وصلت للعميل')),
          if (stage == 3) ...[
            const Text('أدخل كود التسليم من العميل', style: TextStyle(fontWeight: FontWeight.w800, color: kV)),
            const SizedBox(height: 8),
            TextField(
              controller: code,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 10),
              decoration: const InputDecoration(counterText: '', hintText: '••••'),
            ),
            if (err != null) Msg(err!),
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kG),
              onPressed: busy ? null : () => code.text.trim().length == 4 ? run('deliver', code.text.trim()) : setState(() => err = 'أدخل الكود كاملًا'),
              child: const Text('تأكيد التسليم'),
            ),
          ],
        ]),
      ),
    );
  }
}

/* ====================== LOGIN / CLAIM ====================== */
class DriverLogin extends StatefulWidget {
  const DriverLogin({super.key});
  @override
  State<DriverLogin> createState() => _DriverLoginState();
}

class _DriverLoginState extends State<DriverLogin> {
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
      body: ListView(padding: EdgeInsets.fromLTRB(22, MediaQuery.of(context).padding.top + 50, 22, 30), children: [
        Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: kV, borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.two_wheeler, color: kY, size: 40),
        ),
        const SizedBox(height: 16),
        const Text('منصتك — المندوب', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kV)),
        const Text('سجّل الدخول لاستقبال طلبات التوصيل', style: TextStyle(color: kMu)),
        const SizedBox(height: 22),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'البريد الإلكتروني')),
        const SizedBox(height: 10),
        TextField(controller: pass, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'كلمة المرور')),
        if (err != null) Msg(err!),
        const SizedBox(height: 16),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: kV), onPressed: busy ? null : go, child: Text(busy ? 'لحظة…' : 'دخول')),
        const SizedBox(height: 18),
        Box(
          color: kYl,
          border: kYl,
          child: Row(children: [
            const Expanded(child: Text('للعرض: حساب مندوب تجريبي', style: TextStyle(fontWeight: FontWeight.w700, color: kV))),
            TextButton(
              onPressed: () {
                email.text = 'driver@demo-delivery.app';
                pass.text = 'Demo@2026';
                go();
              },
              child: const Text('دخول تجريبي', style: TextStyle(color: kO, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class ClaimScreen extends StatefulWidget {
  const ClaimScreen({super.key});
  @override
  State<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends State<ClaimScreen> {
  final code = TextEditingController();
  String? err;
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: [TextButton(onPressed: () => sb.auth.signOut(), child: const Text('خروج'))]),
      body: ListView(padding: const EdgeInsets.all(22), children: [
        const Text('فعّل حسابك كمندوب', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: kV)),
        const Text('أدخل كود المندوب الذي استلمته من إدارة المنصة.', style: TextStyle(color: kMu)),
        const SizedBox(height: 16),
        TextField(controller: code, textDirection: TextDirection.ltr, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'DRIVER-XXXXXX')),
        if (err != null) Msg(err!),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kV),
          onPressed: busy
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    err = null;
                  });
                  try {
                    await drv.claim(code.text);
                    if (!drv.isDriver) err = 'هذا الكود ليس كود مندوب';
                  } catch (e) {
                    err = dErr(e);
                  }
                  if (mounted) setState(() => busy = false);
                },
          child: const Text('تفعيل'),
        ),
      ]),
    );
  }
}
