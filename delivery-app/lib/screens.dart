import 'package:flutter/material.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

const _icons = <String, IconData>{
  'kebab_dining': Icons.kebab_dining,
  'lunch_dining': Icons.lunch_dining,
  'local_pizza': Icons.local_pizza,
  'cake': Icons.cake,
  'dinner_dining': Icons.dinner_dining,
  'breakfast_dining': Icons.breakfast_dining,
  'set_meal': Icons.set_meal,
  'eco': Icons.eco,
  'local_drink': Icons.local_drink,
  'fastfood': Icons.fastfood,
  'tapas': Icons.tapas,
  'local_cafe': Icons.local_cafe,
  'bakery_dining': Icons.bakery_dining,
  'icecream': Icons.icecream,
  'rice_bowl': Icons.rice_bowl,
  'ramen_dining': Icons.ramen_dining,
  'soup_kitchen': Icons.soup_kitchen,
};
IconData iconOf(dynamic name) => _icons[name] ?? Icons.restaurant;

Widget foodVisual(Map<String, dynamic> x, double size, {Color color = Colors.white}) {
  final url = x['image_url'] as String?;
  if (url != null && url.isNotEmpty) {
    return Image.network(url, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => Icon(iconOf(x['icon']), size: size, color: color));
  }
  return Icon(iconOf(x['icon']), size: size, color: color);
}

/* ====================== SHELL ====================== */
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (!app.loaded) {
          return Scaffold(
            backgroundColor: kO,
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(color: kY, borderRadius: BorderRadius.circular(26)),
                  alignment: Alignment.center,
                  child: const Text('م', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: kV)),
                ),
                const SizedBox(height: 16),
                const Text('منصتك', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 24),
                if (app.loadError == null)
                  const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                else ...[
                  Text(app.loadError!, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 12),
                  TextButton(onPressed: app.loadCatalog, child: const Text('أعد المحاولة', style: TextStyle(color: kY, fontWeight: FontWeight.w800))),
                ]
              ]),
            ),
          );
        }
        final live = app.orders.any((o) => !['delivered', 'rejected'].contains(o['status']));
        return Scaffold(
          body: IndexedStack(index: tab, children: const [HomeScreen(), OrdersScreen(), AccountScreen()]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: kO), label: 'الرئيسية'),
              NavigationDestination(
                  icon: Badge(isLabelVisible: live, backgroundColor: kO, smallSize: 9, child: const Icon(Icons.receipt_long_outlined)),
                  selectedIcon: const Icon(Icons.receipt_long, color: kO),
                  label: 'طلباتي'),
              const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: kO), label: 'حسابي'),
            ],
          ),
        );
      },
    );
  }
}

/* ====================== HOME ====================== */
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String q = '', cat = 'الكل';
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final cats = ['الكل', ...{for (final r in app.rests) r['cat'] as String}];
        final list = app.rests.where((r) {
          final okCat = cat == 'الكل' || r['cat'] == cat;
          final okQ = q.isEmpty || (r['name'] as String).contains(q) || app.menuOf(r['id']).any((m) => (m['name'] as String).contains(q));
          return okCat && okQ;
        }).toList();
        final active = app.orders.where((o) => !['delivered', 'rejected'].contains(o['status'])).toList();
        final zones = app.zones.where((z) => z['active'] == true).toList();
        final z = app.zone;
        return RefreshIndicator(
          color: kO,
          onRefresh: () async {
            await app.loadCatalog();
            await app.loadOrders();
          },
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 12, 18, 18),
                decoration: const BoxDecoration(color: kO, borderRadius: BorderRadius.vertical(bottom: Radius.circular(26))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('التوصيل إلى', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: z['id'] as int?,
                            dropdownColor: Colors.white,
                            iconEnabledColor: Colors.white,
                            isDense: true,
                            selectedItemBuilder: (_) => zones.map((x) => Text('${x['name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))).toList(),
                            items: zones.map((x) => DropdownMenuItem<int>(value: x['id'] as int, child: Text('${x['name']}'))).toList(),
                            onChanged: (v) => v == null ? null : app.setZone(v),
                          ),
                        ),
                      ]),
                    ),
                    const Text('منصتك', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => setState(() => q = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن مطعم أو وجبة',
                      prefixIcon: const Icon(Icons.search, color: kMu),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ]),
              ),
            ),
            if (active.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackScreen(id: active.first['id']))),
                    child: Box(
                      border: kO,
                      child: Row(children: [
                        const Icon(Icons.delivery_dining, color: kO, size: 30),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('طلبك #${active.first['id']} — ${statusLabel(active.first['status']).$1}', style: const TextStyle(fontWeight: FontWeight.w800, color: kV)),
                          Text('${app.rest(active.first['restaurant_id'])['name'] ?? ''} · اضغط للمتابعة', style: const TextStyle(color: kMu, fontSize: 13)),
                        ])),
                        const Pill('تتبع', bg: kOl, fg: kO),
                      ]),
                    ),
                  ),
                ),
              ),
            if (q.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: kV, borderRadius: BorderRadius.circular(20)),
                  child: const Row(children: [
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('خصم 30٪ على أول طلب', style: TextStyle(color: kY, fontWeight: FontWeight.w800, fontSize: 20)),
                      Text('استخدم الكوبون «اهلا» عند الدفع', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ])),
                    Icon(Icons.local_offer, color: kO, size: 40),
                  ]),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                  children: cats
                      .map((c) => Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                              label: Text(c),
                              selected: cat == c,
                              onSelected: (_) => setState(() => cat = c),
                              selectedColor: kOl,
                              labelStyle: TextStyle(color: cat == c ? kO : kV, fontWeight: FontWeight.w700),
                              side: BorderSide(color: cat == c ? kO : Colors.transparent),
                              backgroundColor: kBg,
                              showCheckmark: false,
                              shape: const StadiumBorder(),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
            SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    child: Text(q.isEmpty ? 'مطاعم قريبة منك' : 'نتائج البحث', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kV)))),
            if (list.isEmpty)
              const SliverToBoxAdapter(child: EmptyState(Icons.search_off, 'لا توجد نتائج مطابقة'))
            else
              SliverList.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => RestCard(r: list[i], fee: n(z['fee'])),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ]),
        );
      },
    );
  }
}

class RestCard extends StatelessWidget {
  final Map<String, dynamic> r;
  final double fee;
  const RestCard({super.key, required this.r, required this.fee});
  @override
  Widget build(BuildContext context) {
    final open = r['open'] == true;
    return Opacity(
      opacity: open ? 1 : .6,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: kLn), color: Colors.white),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RestaurantScreen(id: r['id']))),
          child: Column(children: [
            Container(
              height: 120,
              decoration: BoxDecoration(gradient: gradFrom(r['bg'])),
              child: Stack(children: [
                Center(child: foodVisual(r, 58)),
                if (!open)
                  PositionedDirectional(top: 10, start: 10, child: Pill('مغلق${r['opens_at'] != null ? ' · يفتح ${r['opens_at']}' : ''}', bg: kRl, fg: kR))
                else if (r['sort'] == 1)
                  const PositionedDirectional(top: 10, start: 10, child: Pill('الأكثر طلبًا', bg: kYl, fg: Color(0xFF946100))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kV)),
                  Text('${r['cat']} · ${r['eta']} دقيقة · توصيل ${fmt(fee)} $kCur', style: const TextStyle(color: kMu, fontSize: 13)),
                ])),
                Pill('★ ${r['rating']}'),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/* ====================== RESTAURANT ====================== */
class RestaurantScreen extends StatelessWidget {
  final String id;
  const RestaurantScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final r = app.rest(id);
        final items = app.menuOf(id).where((m) => m['available'] == true).toList();
        final secs = <String>[];
        for (final m in items) {
          if (!secs.contains(m['section'])) secs.add(m['section']);
        }
        final open = r['open'] == true;
        final showCart = app.count > 0 && app.cartRid == id;
        return Scaffold(
          body: CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 170,
              pinned: true,
              backgroundColor: kO,
              foregroundColor: Colors.white,
              title: Text('${r['name'] ?? ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(decoration: BoxDecoration(gradient: gradFrom(r['bg'])), child: Center(child: foodVisual(r, 80))),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${r['name']}', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: kV))),
                    Pill('★ ${r['rating']} (${r['rating_cnt']})'),
                  ]),
                  Text('${r['eta']} دقيقة · توصيل ${fmt(app.fee)} $kCur · الحد الأدنى ${fmt(n(r['min_order']))} $kCur', style: const TextStyle(color: kMu, fontSize: 13)),
                  if (!open) Msg('المطعم مغلق الآن${r['opens_at'] != null ? ' ويفتح ${r['opens_at']}' : ''}. تصفح المنيو واطلب لاحقًا.'),
                ]),
              ),
            ),
            for (final s in secs) ...[
              SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 4), child: Text(s, style: const TextStyle(fontWeight: FontWeight.w800, color: kV, fontSize: 16)))),
              SliverList.list(children: items.where((m) => m['section'] == s).map((m) => ItemRow(m: m, open: open)).toList()),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ]),
          bottomNavigationBar: showCart
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                    child: FilledButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
                      child: Row(children: [
                        Pill('${app.count}', bg: Colors.white24, fg: Colors.white),
                        const SizedBox(width: 10),
                        const Text('عرض السلة'),
                        const Spacer(),
                        Text('${fmt(app.sub)} $kCur'),
                      ]),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class ItemRow extends StatelessWidget {
  final Map<String, dynamic> m;
  final bool open;
  const ItemRow({super.key, required this.m, required this.open});
  @override
  Widget build(BuildContext context) {
    final q = app.cartRid == m['restaurant_id'] ? app.qtyOf(m['id']) : 0;
    void openSheet() {
      if (!open) {
        toast(context, 'المطعم مغلق الآن', error: true);
        return;
      }
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
          builder: (_) => ItemSheet(m: m));
    }

    return InkWell(
      onTap: openSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kLn))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text('${m['descr'] ?? ''}', style: const TextStyle(color: kMu, fontSize: 13)),
            const SizedBox(height: 6),
            Text('${fmt(n(m['price']))} $kCur${m['options'] != null ? ' · خيارات' : ''}', style: const TextStyle(fontWeight: FontWeight.w800, color: kV)),
          ])),
          const SizedBox(width: 12),
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: Center(child: foodVisual(m, 40, color: kV.withAlpha(190))),
              ),
              if (open)
                PositionedDirectional(
                  bottom: -6,
                  end: -2,
                  child: GestureDetector(
                    onTap: () {
                      if (m['options'] != null) {
                        openSheet();
                      } else {
                        final cleared = app.addLine(m, 0, [], 1, '');
                        if (cleared) toast(context, 'بدأنا سلة جديدة من ${app.rest(m['restaurant_id'])['name']}');
                      }
                    },
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 34),
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: q > 0 ? kO : Colors.white,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: const [BoxShadow(color: Color(0x22301A5B), blurRadius: 12, offset: Offset(0, 4))]),
                      child: q > 0
                          ? Text('$q', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))
                          : const Icon(Icons.add, color: kO, size: 22),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class ItemSheet extends StatefulWidget {
  final Map<String, dynamic> m;
  const ItemSheet({super.key, required this.m});
  @override
  State<ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<ItemSheet> {
  int? size;
  final adds = <int>[];
  int q = 1;
  final note = TextEditingController();
  @override
  void initState() {
    super.initState();
    if (widget.m['options'] == null) size = 0;
  }

  double get unit {
    final m = widget.m, o = m['options'];
    double u = n(m['price']);
    if (o != null) {
      if (size != null) u += n(o['size'][size][1]);
      for (final a in adds) {
        u += n(o['add'][a][1]);
      }
    }
    return u;
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m, o = m['options'];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              height: 150,
              width: double.infinity,
              decoration: const BoxDecoration(color: kBg, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
              clipBehavior: Clip.antiAlias,
              child: Center(child: foodVisual(m, 80, color: kV.withAlpha(190))),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${m['name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kV))),
                  Text('${fmt(n(m['price']))} $kCur', style: const TextStyle(fontWeight: FontWeight.w800, color: kV)),
                ]),
                Text('${m['descr'] ?? ''}', style: const TextStyle(color: kMu)),
                if (o != null) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    const Expanded(child: Text('الحجم', style: TextStyle(fontWeight: FontWeight.w800, color: kV))),
                    Pill('إجباري', bg: size == null ? kRl : kGl, fg: size == null ? kR : kG),
                  ]),
                  for (var i = 0; i < (o['size'] as List).length; i++)
                    InkWell(
                      onTap: () => setState(() => size = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Icon(size == i ? Icons.radio_button_checked : Icons.radio_button_off, color: size == i ? kO : kLn),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${o['size'][i][0]}')),
                          if (n(o['size'][i][1]) > 0) Text('+${fmt(n(o['size'][i][1]))} $kCur', style: const TextStyle(color: kMu)),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Text('إضافات (اختياري)', style: TextStyle(fontWeight: FontWeight.w800, color: kV)),
                  for (var i = 0; i < (o['add'] as List).length; i++)
                    InkWell(
                      onTap: () => setState(() => adds.contains(i) ? adds.remove(i) : adds.add(i)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Icon(adds.contains(i) ? Icons.check_box : Icons.check_box_outline_blank, color: adds.contains(i) ? kO : kLn),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${o['add'][i][0]}')),
                          Text('+${fmt(n(o['add'][i][1]))} $kCur', style: const TextStyle(color: kMu)),
                        ]),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                TextField(controller: note, maxLength: 80, decoration: const InputDecoration(hintText: 'ملاحظة: بدون بصل…', counterText: '')),
                const SizedBox(height: 14),
                Row(children: [
                  Stepper2(q: q, onPlus: () => setState(() => q = q < 50 ? q + 1 : q), onMinus: () => setState(() => q = q > 1 ? q - 1 : 1)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (size == null) {
                          toast(context, 'اختر الحجم أولًا', error: true);
                          return;
                        }
                        final cleared = app.addLine(m, size!, adds, q, note.text.trim());
                        Navigator.pop(context);
                        if (cleared) toast(context, 'بدأنا سلة جديدة من ${app.rest(m['restaurant_id'])['name']}');
                      },
                      child: Text('أضف إلى السلة · ${fmt(unit * q)} $kCur'),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/* ====================== CART ====================== */
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final cpn = TextEditingController();
  String? cpnErr;
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (app.count == 0) {
          return Scaffold(appBar: AppBar(title: const Text('السلة')), body: EmptyState(Icons.shopping_bag_outlined, 'سلتك فارغة', action: 'تصفح المطاعم', onAction: () => Navigator.popUntil(context, (r) => r.isFirst)));
        }
        final r = app.rest(app.cartRid);
        final short = n(r['min_order']) - app.sub;
        final open = r['open'] == true;
        return Scaffold(
          appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('سلتك'), Text('${r['name']}', style: const TextStyle(fontSize: 13, color: kMu))])),
          body: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 24), children: [
            for (var i = 0; i < app.lines.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kLn))),
                child: Row(children: [
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(app.lines[i].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (app.lines[i].extra.isNotEmpty) Text(app.lines[i].extra, style: const TextStyle(color: kMu, fontSize: 13)),
                    Text('${fmt(app.lines[i].unit * app.lines[i].q)} $kCur', style: const TextStyle(fontWeight: FontWeight.w800, color: kV)),
                  ])),
                  Stepper2(q: app.lines[i].q, trashAtOne: true, onPlus: () => app.changeQty(i, 1), onMinus: () => app.changeQty(i, -1)),
                ]),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.add, color: kO),
                label: const Text('أضف أصنافًا أخرى', style: TextStyle(color: kO, fontWeight: FontWeight.w800)),
              ),
            ),
            Row(children: [
              Expanded(child: TextField(controller: cpn, decoration: const InputDecoration(hintText: 'كوبون الخصم (جرّب: اهلا)'))),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kVl, foregroundColor: kV, minimumSize: const Size(90, 48)),
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          final e = await app.applyCoupon(cpn.text);
                          setState(() {
                            busy = false;
                            cpnErr = e;
                          });
                        },
                  child: const Text('تطبيق'),
                ),
              ),
            ]),
            if (cpnErr != null) Msg(cpnErr!),
            if (app.coupon != null) Msg('${app.coupon!['label']}', ok: true),
            const SizedBox(height: 14),
            Line('المجموع الفرعي', '${fmt(app.sub)} $kCur'),
            Line('التوصيل إلى ${app.zone['name']}', '${fmt(app.fee)} $kCur'),
            if (app.discount > 0) Line('الخصم', '−${fmt(app.discount)} $kCur', color: kG),
            const Divider(color: kLn),
            Line('الإجمالي', '${fmt(app.total)} $kCur', total: true),
            if (short > 0) Msg('أضف ${fmt(short)} $kCur للوصول إلى الحد الأدنى للطلب'),
            if (!open) const Msg('المطعم مغلق الآن'),
          ]),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: FilledButton(
                onPressed: short > 0 || !open
                    ? null
                    : () async {
                        if (app.session == null) {
                          final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AuthScreen(forCheckout: true)));
                          if (ok != true || !context.mounted) return;
                        }
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                      },
                child: const Text('تابع للدفع'),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ====================== AUTH ====================== */
class AuthScreen extends StatefulWidget {
  final bool forCheckout;
  const AuthScreen({super.key, this.forCheckout = false});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool signup = false, busy = false;
  String? err, ok;
  final name = TextEditingController(), phone = TextEditingController(), email = TextEditingController(), pass = TextEditingController();

  Future<void> submit() async {
    setState(() {
      err = ok = null;
      busy = true;
    });
    try {
      if (signup) {
        final p = phone.text.replaceAll(RegExp(r'\D'), '');
        if (name.text.trim().isEmpty) throw 'اكتب اسمك';
        if (!RegExp(r'^5\d{8}$').hasMatch(p)) throw 'رقم الجوال يجب أن يبدأ بـ 5 ويتكون من 9 أرقام';
        app.pendingName = name.text.trim();
        app.pendingPhone = p;
        final res = await sb.auth.signUp(email: email.text.trim(), password: pass.text, data: {'name': name.text.trim(), 'phone': p});
        if (res.session == null) {
          setState(() {
            busy = false;
            signup = false;
            ok = 'أرسلنا رابط تأكيد إلى بريدك. أكّده ثم سجّل الدخول.';
          });
          return;
        }
      } else {
        await sb.auth.signInWithPassword(email: email.text.trim(), password: pass.text);
      }
      await app.loadProfile();
      await app.loadOrders();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        busy = false;
        err = e is String ? e : errMsg(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget lbl(String t) => Padding(padding: const EdgeInsets.only(top: 12, bottom: 6), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, color: kV, fontSize: 13)));
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 30), children: [
        Text(widget.forCheckout ? 'سجّل الدخول لإتمام طلبك' : 'أهلًا بك في منصتك', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: kV)),
        Text(widget.forCheckout ? 'سلتك محفوظة.' : 'سجّل الدخول لمتابعة طلباتك.', style: const TextStyle(color: kMu)),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('تسجيل الدخول')), ButtonSegment(value: true, label: Text('حساب جديد'))],
          selected: {signup},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() {
            signup = s.first;
            err = ok = null;
          }),
        ),
        if (signup) ...[
          lbl('الاسم'),
          TextField(controller: name, decoration: const InputDecoration(hintText: 'محمد')),
          lbl('رقم الجوال'),
          TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              maxLength: 9,
              decoration: const InputDecoration(hintText: '5xxxxxxxx', prefixText: '+966 ', counterText: '')),
        ],
        lbl('البريد الإلكتروني'),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'name@email.com')),
        lbl('كلمة المرور'),
        TextField(controller: pass, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: '6 أحرف على الأقل')),
        if (err != null) Msg(err!),
        if (ok != null) Msg(ok!, ok: true),
        const SizedBox(height: 18),
        FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'لحظة…' : signup ? 'أنشئ حسابي' : 'دخول')),
        const SizedBox(height: 18),
        Box(
          color: kYl,
          border: kYl,
          child: Row(children: [
            const Expanded(child: Text('للعرض: حساب عميل تجريبي', style: TextStyle(fontWeight: FontWeight.w700, color: kV))),
            TextButton(
              onPressed: () {
                setState(() => signup = false);
                email.text = 'customer@demo-delivery.app';
                pass.text = 'Demo@2026';
                submit();
              },
              child: const Text('دخول تجريبي', style: TextStyle(color: kO, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ]),
    );
  }
}

/* ====================== CHECKOUT ====================== */
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String pay = 'cash';
  bool busy = false;
  late final addr = TextEditingController(text: app.addr);
  final note = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (app.count == 0) return const Scaffold(body: SizedBox());
        final r = app.rest(app.cartRid);
        final wal = n(app.profile?['wallet']);
        final short = pay == 'wallet' && app.total > wal;
        final zones = app.zones.where((z) => z['active'] == true).toList();
        final pms = [
          ('cash', Icons.payments_outlined, 'نقدًا عند الاستلام', ''),
          ('card', Icons.credit_card, 'بطاقة مدى / فيزا', 'الدفع الإلكتروني يُربط بالبوابة عند الإطلاق'),
          ('wallet', Icons.account_balance_wallet_outlined, 'المحفظة', 'الرصيد: ${fmt(wal)} $kCur'),
        ];
        return Scaffold(
          appBar: AppBar(title: const Text('إتمام الطلب')),
          body: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 24), children: [
            const Text('منطقة التوصيل', style: TextStyle(fontWeight: FontWeight.w700, color: kV, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: app.zone['id'] as int?,
              items: zones.map((z) => DropdownMenuItem<int>(value: z['id'] as int, child: Text('${z['name']} — ${fmt(n(z['fee']))} $kCur'))).toList(),
              onChanged: (v) => v == null ? null : app.setZone(v),
            ),
            const SizedBox(height: 12),
            const Text('العنوان بالتفصيل', style: TextStyle(fontWeight: FontWeight.w700, color: kV, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(controller: addr, maxLength: 150, decoration: const InputDecoration(hintText: 'الشارع، رقم المبنى، الشقة', counterText: '')),
            const SizedBox(height: 12),
            Box(
                child: Row(children: [
              const Icon(Icons.schedule, color: kV),
              const SizedBox(width: 8),
              const Expanded(child: Text('وقت التوصيل', style: TextStyle(fontWeight: FontWeight.w800, color: kV))),
              Text('الآن · ${r['eta']} دقيقة', style: const TextStyle(color: kMu)),
            ])),
            const SizedBox(height: 18),
            const Text('طريقة الدفع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kV)),
            const SizedBox(height: 10),
            for (final p in pms)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => pay = p.$1),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: pay == p.$1 ? kOl : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: pay == p.$1 ? kO : kLn, width: 1.5)),
                    child: Row(children: [
                      Icon(pay == p.$1 ? Icons.radio_button_checked : Icons.radio_button_off, color: pay == p.$1 ? kO : kLn),
                      const SizedBox(width: 10),
                      Icon(p.$2, color: kV),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.$3, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (p.$4.isNotEmpty) Text(p.$4, style: const TextStyle(color: kMu, fontSize: 12)),
                      ])),
                    ]),
                  ),
                ),
              ),
            if (short) const Msg('رصيد المحفظة لا يكفي. اختر طريقة أخرى.'),
            const SizedBox(height: 6),
            TextField(controller: note, maxLength: 150, decoration: const InputDecoration(hintText: 'ملاحظة للمندوب: اتصل عند الوصول', counterText: '')),
            const SizedBox(height: 8),
            Line('الإجمالي', '${fmt(app.total)} $kCur', total: true),
          ]),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: FilledButton(
                onPressed: busy || short
                    ? null
                    : () async {
                        final a = addr.text.trim();
                        if (a.length < 4) {
                          toast(context, 'اكتب عنوان التوصيل', error: true);
                          return;
                        }
                        app.setAddr(a);
                        setState(() => busy = true);
                        try {
                          final o = await app.placeOrder(pay: pay, note: note.text.trim(), address: a);
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => TrackScreen(id: o['id'])), (r) => r.isFirst);
                        } catch (e) {
                          if (!context.mounted) return;
                          setState(() => busy = false);
                          toast(context, errMsg(e), error: true);
                        }
                      },
                child: Text(busy ? 'جارٍ الإرسال…' : 'أكّد الطلب · ${fmt(app.total)} $kCur'),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ====================== TRACK ====================== */
class TrackScreen extends StatelessWidget {
  final int id;
  const TrackScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final o = app.order(id);
        if (o == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator(color: kO)));
        final r = app.rest(o['restaurant_id']);
        final st = o['status'] as String;
        if (st == 'rejected') {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(Icons.sentiment_dissatisfied_outlined, 'اعتذر المطعم عن طلبك.\n${o['pay_method'] == 'cash' ? 'لم يتم خصم أي مبلغ.' : 'تم استرداد المبلغ كاملًا.'}',
                action: 'اختر مطعمًا آخر', onAction: () => Navigator.popUntil(context, (r) => r.isFirst)),
          );
        }
        final idx = {'new': 0, 'preparing': 1, 'ready': 1, 'picked': 2, 'delivered': 3}[st] ?? 0;
        const titles = {
          'new': 'بانتظار تأكيد المطعم…',
          'preparing': 'المطعم يجهّز طلبك',
          'ready': 'طلبك جاهز وبانتظار المندوب',
          'picked': 'المندوب في الطريق إليك',
          'delivered': 'تم التوصيل، بالهناء والشفاء!'
        };
        const steps = ['تم الإرسال', 'يُجهَّز', 'في الطريق', 'وصل'];
        final hasDriver = o['driver_id'] != null;
        final progress = st == 'delivered' ? 1.0 : st == 'picked' ? 0.35 + 0.18 * (o['driver_stage'] as int? ?? 1) : 0.0;
        return Scaffold(
          appBar: AppBar(title: Text('طلب #$id')),
          body: ListView(padding: EdgeInsets.zero, children: [
            SizedBox(
              height: 220,
              child: LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth;
                return Stack(children: [
                  Container(color: const Color(0xFFEEF1E9)),
                  Positioned(left: 0, right: 0, top: 60, child: Container(height: 14, color: Colors.white)),
                  Positioned(left: 0, right: 0, top: 160, child: Container(height: 14, color: Colors.white)),
                  Positioned(left: w * .2, top: 0, bottom: 0, child: Container(width: 14, color: Colors.white)),
                  Positioned(left: w * .75, top: 0, bottom: 0, child: Container(width: 14, color: Colors.white)),
                  Positioned(left: w * .2 - 14, top: 34, child: const Icon(Icons.storefront, color: kO, size: 40)),
                  Positioned(left: w * .75 - 12, top: 132, child: const Icon(Icons.home, color: kV, size: 40)),
                  if (hasDriver)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 900),
                      left: w * .2 + (w * .55) * progress - 8,
                      top: 50 + 100 * progress,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: kV, shape: BoxShape.circle, border: Border.all(color: kY, width: 4)),
                        child: const Icon(Icons.two_wheeler, color: Colors.white, size: 22),
                      ),
                    ),
                ]);
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titles[st] ?? '', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kV)),
                Text('${r['name'] ?? ''}${st == 'preparing' || st == 'ready' ? ' · يصل خلال ${(o['prep_min'] ?? 15) + 10} دقيقة تقريبًا' : ''}', style: const TextStyle(color: kMu)),
                const SizedBox(height: 16),
                Row(children: [
                  for (var k = 0; k < 4; k++) ...[
                    Column(children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: k <= idx ? kO : kLn,
                        child: k <= idx ? const Icon(Icons.check, size: 16, color: Colors.white) : Text('${k + 1}', style: const TextStyle(fontSize: 12, color: kMu)),
                      ),
                      const SizedBox(height: 4),
                      Text(steps[k], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: k <= idx ? kV : kMu)),
                    ]),
                    if (k < 3) Expanded(child: Container(height: 3, margin: const EdgeInsets.only(bottom: 18), color: k < idx ? kO : kLn)),
                  ]
                ]),
                const SizedBox(height: 14),
                if (hasDriver && st != 'delivered') ...[
                  Box(
                      child: Row(children: [
                    const CircleAvatar(backgroundColor: kVl, child: Icon(Icons.two_wheeler, color: kV)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(st == 'picked' ? 'المندوب في الطريق' : 'المندوب متجه للمطعم', style: const TextStyle(fontWeight: FontWeight.w800)),
                      const Text('سيتصل بك عند الوصول', style: TextStyle(color: kMu, fontSize: 13)),
                    ])),
                  ])),
                  const SizedBox(height: 10),
                  Box(
                    color: kYl,
                    border: const Color(0xFFF5E2A8),
                    child: Row(children: [
                      const Expanded(child: Text('كود التسليم — أعطه للمندوب')),
                      Text('${o['delivery_code']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kV, letterSpacing: 3)),
                    ]),
                  ),
                ],
                const SizedBox(height: 14),
                const Text('تفاصيل الطلب', style: TextStyle(fontWeight: FontWeight.w800, color: kV)),
                for (final it in (o['items'] as List)) Line('${it['q']}× ${it['name']}', fmt(n(it['q']) * n(it['price']))),
                Line('التوصيل', fmt(n(o['fee']))),
                if (n(o['discount']) > 0) Line('الخصم', '−${fmt(n(o['discount']))}', color: kG),
                const Divider(color: kLn),
                Line('الإجمالي · ${payLabel[o['pay_method']]}', '${fmt(n(o['total']))} $kCur', total: true),
                const SizedBox(height: 14),
                if (st == 'delivered' && o['rating_food'] == null)
                  FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RateScreen(id: id))), child: const Text('قيّم طلبك')),
                if (o['rating_food'] != null) Msg('شكرًا لتقييمك ★ ${o['rating_food']}', ok: true),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class RateScreen extends StatefulWidget {
  final int id;
  const RateScreen({super.key, required this.id});
  @override
  State<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends State<RateScreen> {
  int f = 0, d = 0;
  bool busy = false;
  final tags = <String>[];
  @override
  Widget build(BuildContext context) {
    Widget stars(int v, void Function(int) set) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
            5, (i) => IconButton(onPressed: () => set(i + 1), icon: Icon(i < v ? Icons.star_rounded : Icons.star_outline_rounded, color: i < v ? kY : kLn, size: 34))));
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Icon(Icons.celebration, color: kO, size: 56),
        const SizedBox(height: 8),
        const Center(child: Text('كيف كان طلبك؟', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: kV))),
        const SizedBox(height: 18),
        Row(children: [const Expanded(child: Text('الطعام', style: TextStyle(fontWeight: FontWeight.w800))), stars(f, (v) => setState(() => f = v))]),
        Row(children: [const Expanded(child: Text('المندوب', style: TextStyle(fontWeight: FontWeight.w800))), stars(d, (v) => setState(() => d = v))]),
        const SizedBox(height: 12),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['سريع', 'ساخن', 'كمية ممتازة', 'تغليف جيد', 'تأخر']
                .map((t) => FilterChip(
                      label: Text(t),
                      selected: tags.contains(t),
                      showCheckmark: false,
                      selectedColor: kOl,
                      onSelected: (_) => setState(() => tags.contains(t) ? tags.remove(t) : tags.add(t)),
                    ))
                .toList()),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: f == 0 || d == 0 || busy
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    await app.rate(widget.id, f, d, tags);
                    if (!context.mounted) return;
                    toast(context, 'شكرًا! تقييمك يساعدنا');
                    Navigator.popUntil(context, (r) => r.isFirst);
                  } catch (e) {
                    if (!context.mounted) return;
                    setState(() => busy = false);
                    toast(context, errMsg(e), error: true);
                  }
                },
          child: const Text('أرسل التقييم'),
        ),
      ]),
    );
  }
}

/* ====================== ORDERS / ACCOUNT ====================== */
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('طلباتي')),
        body: app.session == null
            ? EmptyState(Icons.receipt_long_outlined, 'سجّل الدخول لترى طلباتك', action: 'تسجيل الدخول', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())))
            : app.orders.isEmpty
                ? const EmptyState(Icons.receipt_long_outlined, 'لا توجد طلبات بعد')
                : RefreshIndicator(
                    color: kO,
                    onRefresh: app.loadOrders,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(18),
                      itemCount: app.orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final o = app.orders[i];
                        final l = statusLabel(o['status']);
                        final dt = DateTime.tryParse('${o['created_at']}')?.toLocal();
                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackScreen(id: o['id']))),
                          child: Box(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text('${app.rest(o['restaurant_id'])['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, color: kV))),
                              Pill(l.$1, bg: l.$2, fg: l.$3),
                            ]),
                            Text('#${o['id']} · ${dt == null ? '' : '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}'} · ${fmt(n(o['total']))} $kCur',
                                style: const TextStyle(color: kMu, fontSize: 13)),
                          ])),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = app.profile;
        return Scaffold(
          appBar: AppBar(title: const Text('حسابي')),
          body: app.session == null
              ? EmptyState(Icons.person_outline, 'لم تسجّل الدخول بعد', action: 'تسجيل الدخول', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())))
              : ListView(padding: const EdgeInsets.all(18), children: [
                  Box(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p?['name'] ?? '—'}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(app.session!.user.email ?? '', style: const TextStyle(color: kMu, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Expanded(child: Text('رصيد المحفظة')),
                      Text('${fmt(n(p?['wallet']))} $kCur', style: const TextStyle(fontWeight: FontWeight.w800, color: kG)),
                    ]),
                  ])),
                  if (app.role != 'customer') ...[
                    const SizedBox(height: 12),
                    const Msg('هذا الحساب مخصص للشركاء. تطبيق المطعم والمندوب قادم في المرحلة التالية.'),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kRl, foregroundColor: kR),
                    onPressed: () => sb.auth.signOut(),
                    child: const Text('تسجيل الخروج'),
                  ),
                ]),
        );
      },
    );
  }
}

