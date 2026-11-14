import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';

const kUrl = 'https://quicdsxjpxsoksvhwxcq.supabase.co';
const kKey = 'sb_publishable_UwjFttlllFmnqbnWxYmkXw_2rpP0eFJ';

SupabaseClient get sb => Supabase.instance.client;

class CartLine {
  final String itemId;
  final String name;
  final String extra;
  final double unit;
  int q;
  final int size;
  final List<int> adds;
  final String note;
  CartLine({required this.itemId, required this.name, required this.extra, required this.unit, required this.q, required this.size, required this.adds, required this.note});
  String get key => '$itemId|$size|${(List.of(adds)..sort()).join(',')}|$note';
  Map<String, dynamic> toJson() => {'item_id': itemId, 'name': name, 'extra': extra, 'unit': unit, 'q': q, 'size': size, 'adds': adds, 'note': note};
  Map<String, dynamic> toRpc() => {'item_id': itemId, 'q': q, 'size': size, 'adds': adds, 'note': note};
  static CartLine fromJson(Map<String, dynamic> j) => CartLine(
      itemId: j['item_id'], name: j['name'], extra: j['extra'] ?? '', unit: n(j['unit']), q: j['q'] ?? 1, size: j['size'] ?? 0,
      adds: List<int>.from(j['adds'] ?? const []), note: j['note'] ?? '');
}

const kErr = {
  'not_authenticated': 'سجّل الدخول أولًا',
  'restaurant_closed': 'المطعم مغلق الآن',
  'item_unavailable': 'أحد الأصناف لم يعد متاحًا، حدّث السلة',
  'below_min': 'الطلب أقل من الحد الأدنى',
  'bad_coupon': 'الكوبون غير صالح أو منتهي',
  'wallet_low': 'رصيد المحفظة لا يكفي',
  'bad_zone': 'منطقة التوصيل غير متاحة',
  'empty_cart': 'السلة فارغة',
  'bad_option': 'اختيار غير صالح',
  'forbidden': 'ليست لديك صلاحية',
  'Invalid login credentials': 'البريد أو كلمة المرور غير صحيحة',
  'User already registered': 'هذا البريد مسجّل بالفعل، سجّل الدخول',
  'Email not confirmed': 'أكّد بريدك الإلكتروني أولًا',
};

String errMsg(Object e) {
  final m = e is PostgrestException ? e.message : e is AuthException ? e.message : e.toString();
  for (final k in kErr.keys) {
    if (m.contains(k)) return kErr[k]!;
  }
  if (m.toLowerCase().contains('password')) return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
  if (m.contains('SocketException') || m.toLowerCase().contains('network') || m.contains('Failed host lookup')) return 'تعذّر الاتصال، تحقق من الإنترنت';
  return 'حدث خطأ، حاول مرة أخرى';
}

class AppState extends ChangeNotifier {
  List<Map<String, dynamic>> rests = [], menu = [], zones = [], orders = [];
  Map<String, dynamic>? profile;
  bool loaded = false;
  String? loadError;
  String? cartRid;
  List<CartLine> lines = [];
  int? zoneId;
  String addr = '';
  Map<String, dynamic>? coupon;
  SharedPreferences? _p;
  RealtimeChannel? _ch;
  Timer? _deb;
  String? pendingName, pendingPhone;

  Session? get session => sb.auth.currentSession;
  String? get uid => sb.auth.currentUser?.id;
  String get role => profile?['role'] ?? 'customer';

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    try {
      final c = jsonDecode(_p!.getString('cart') ?? '{}') as Map<String, dynamic>;
      cartRid = c['rid'];
      lines = (c['lines'] as List? ?? []).map((e) => CartLine.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {}
    zoneId = _p!.getInt('zone');
    addr = _p!.getString('addr') ?? '';
    sb.auth.onAuthStateChange.listen((d) {
      if (d.event == AuthChangeEvent.signedIn || d.event == AuthChangeEvent.signedOut || d.event == AuthChangeEvent.initialSession) {
        _onSession();
      }
    });
    loadCatalog();
  }

  Future<void> loadCatalog() async {
    loadError = null;
    notifyListeners();
    try {
      final r = await Future.wait([
        sb.from('dl_restaurants').select().order('sort'),
        sb.from('dl_menu_items').select().order('sort'),
        sb.from('dl_zones').select().order('id'),
      ]);
      rests = List<Map<String, dynamic>>.from(r[0]);
      menu = List<Map<String, dynamic>>.from(r[1]);
      zones = List<Map<String, dynamic>>.from(r[2]);
      if (cartRid != null && !rests.any((x) => x['id'] == cartRid)) clearCart();
      loaded = true;
    } catch (e) {
      loadError = errMsg(e);
    }
    notifyListeners();
  }

  Future<void> _onSession() async {
    if (session != null) {
      await loadProfile();
      await loadOrders();
    } else {
      profile = null;
      orders = [];
    }
    _subscribe();
    notifyListeners();
  }

  Future<void> loadProfile() async {
    if (session == null) return;
    try {
      final d = await sb.rpc('dl_ensure_profile', params: {'p_name': pendingName, 'p_phone': pendingPhone});
      profile = Map<String, dynamic>.from(d);
      pendingName = pendingPhone = null;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> loadOrders() async {
    if (session == null) return;
    try {
      final d = await sb.from('dl_orders').select().eq('customer_id', uid!).order('created_at', ascending: false).limit(100);
      orders = List<Map<String, dynamic>>.from(d);
      notifyListeners();
    } catch (_) {}
  }

  void _subscribe() {
    if (_ch != null) sb.removeChannel(_ch!);
    _ch = sb
        .channel('dl-app')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'dl_orders', callback: (_) {
          _deb?.cancel();
          _deb = Timer(const Duration(milliseconds: 250), loadOrders);
        })
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'dl_restaurants', callback: (_) => loadCatalog())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'dl_menu_items', callback: (_) => loadCatalog())
        .subscribe();
  }

  Map<String, dynamic> rest(String? id) => rests.firstWhere((r) => r['id'] == id, orElse: () => <String, dynamic>{});
  List<Map<String, dynamic>> menuOf(String id) => menu.where((m) => m['restaurant_id'] == id).toList();
  Map<String, dynamic> get zone {
    final act = zones.where((z) => z['active'] == true).toList();
    if (act.isEmpty) return {'id': null, 'name': '—', 'fee': 0};
    return act.firstWhere((z) => z['id'] == zoneId, orElse: () => act.first);
  }

  void setZone(int id) {
    zoneId = id;
    _p?.setInt('zone', id);
    notifyListeners();
  }

  void setAddr(String a) {
    addr = a;
    _p?.setString('addr', a);
  }

  int get count => lines.fold(0, (a, l) => a + l.q);
  double get sub => lines.fold(0.0, (a, l) => a + l.unit * l.q);
  double get discount => coupon == null ? 0 : [n(coupon!['max_off']), sub * n(coupon!['pct']) / 100].reduce((a, b) => a < b ? a : b);
  double get fee => n(zone['fee']);
  double get total => sub + fee - discount;
  int qtyOf(String itemId) => lines.where((l) => l.itemId == itemId).fold(0, (a, l) => a + l.q);

  /// returns true if a previous cart from another restaurant was cleared
  bool addLine(Map<String, dynamic> m, int size, List<int> adds, int q, String note) {
    bool cleared = false;
    if (cartRid != null && cartRid != m['restaurant_id'] && lines.isNotEmpty) {
      lines = [];
      coupon = null;
      cleared = true;
    }
    cartRid = m['restaurant_id'];
    final o = m['options'];
    double unit = n(m['price']);
    final ex = <String>[];
    if (o != null) {
      unit += n(o['size'][size][1]);
      ex.add('${o['size'][size][0]}');
      for (final a in adds) {
        unit += n(o['add'][a][1]);
        ex.add('${o['add'][a][0]}');
      }
    }
    final line = CartLine(itemId: m['id'], name: m['name'], extra: [ex.join('، '), note].where((s) => s.isNotEmpty).join(' · '), unit: unit, q: q, size: size, adds: List.of(adds), note: note);
    final same = lines.where((l) => l.key == line.key);
    if (same.isNotEmpty) {
      same.first.q += q;
    } else {
      lines.add(line);
    }
    _saveCart();
    notifyListeners();
    return cleared;
  }

  void changeQty(int i, int d) {
    lines[i].q += d;
    if (lines[i].q <= 0) lines.removeAt(i);
    if (lines.isEmpty) {
      cartRid = null;
      coupon = null;
    }
    _saveCart();
    notifyListeners();
  }

  void clearCart() {
    lines = [];
    cartRid = null;
    coupon = null;
    _saveCart();
    notifyListeners();
  }

  void _saveCart() => _p?.setString('cart', jsonEncode({'rid': cartRid, 'lines': lines.map((l) => l.toJson()).toList()}));

  Future<String?> applyCoupon(String code) async {
    final c = code.trim().replaceAll(RegExp('[إأآ]'), 'ا');
    if (c.isEmpty) return 'اكتب كود الكوبون أولًا';
    if (session == null) return 'سجّل الدخول لتطبيق الكوبون';
    try {
      final d = await sb.rpc('dl_check_coupon', params: {'p_code': c});
      if (d == null) {
        coupon = null;
        notifyListeners();
        return 'هذا الكوبون غير صالح أو منتهي';
      }
      coupon = Map<String, dynamic>.from(d);
      notifyListeners();
      return null;
    } catch (e) {
      return errMsg(e);
    }
  }

  Future<Map<String, dynamic>> placeOrder({required String pay, required String note, required String address}) async {
    final z = zone;
    final d = await sb.rpc('dl_place_order', params: {
      'p_rest': cartRid,
      'p_lines': lines.map((l) => l.toRpc()).toList(),
      'p_pay': pay,
      'p_coupon': coupon?['code'],
      'p_note': note,
      'p_address': '${z['name']} — $address',
      'p_zone': z['id'],
    });
    final o = Map<String, dynamic>.from(d);
    orders.insert(0, o);
    clearCart();
    await loadProfile();
    return o;
  }

  Future<void> rate(int id, int f, int dr, List<String> tags) async {
    await sb.rpc('dl_order_action', params: {'p_id': id, 'p_action': 'rate', 'p_arg': '$f|$dr|${tags.join(',')}'});
    await loadOrders();
  }

  Map<String, dynamic>? order(int id) {
    for (final o in orders) {
      if (o['id'] == id) return o;
    }
    return null;
  }
}

final app = AppState();
