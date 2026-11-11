import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../components/app_logo.dart';
import '../components/order_card.dart';
import '../components/refreshable_empty_view.dart';
import '../core/app_events.dart';
import '../core/app_notification.dart';
import '../core/app_theme.dart';
import '../core/db_helper.dart';
import '../core/order_delivery_helper.dart';
import '../core/stock_movement_helper.dart';

class WaitingOrdersScreen extends StatefulWidget {
  const WaitingOrdersScreen({super.key});
  @override
  State<WaitingOrdersScreen> createState() => _WaitingOrdersScreenState();
}

class _WaitingOrdersScreenState extends State<WaitingOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  final Set<int> _expandedOrderIds = {};
  String? _filterDate;
  String _filterCustomer = '';
  String _filterCategory = '';
  String _filterOrderType = 'all'; // 'all', 'نمطي', 'أوردر'

  @override
  void initState() {
    super.initState();
    _loadOrders();
    AppEvents.instance.refreshNotifier.addListener(_loadOrders);
  }

  @override
  void dispose() {
    AppEvents.instance.refreshNotifier.removeListener(_loadOrders);
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final db = await DBHelper.instance.database;
    final data = await db.query('orders',
        where: "status = 'waiting'", orderBy: 'delivery_date ASC');
    if (mounted) {
      setState(() => _orders = data);
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    return _orders.where((o) {
      final matchDate =
          _filterDate == null || o['delivery_date'] == _filterDate;
      final matchCust = _filterCustomer.isEmpty ||
          (o['customer_name'] ?? '').toString().trim() == _filterCustomer.trim();
      final matchCat = _filterCategory.isEmpty ||
          (o['category_name'] ?? '').toString().trim() == _filterCategory.trim();

      bool matchType = true;
      if (_filterOrderType == 'نمطي') {
        final t = (o['order_type'] ?? '').toString().trim();
        matchType = (t == 'نمطي' || t == 'نمطى');
      } else if (_filterOrderType == 'أوردر') {
        final t = (o['order_type'] ?? '').toString().trim();
        matchType = (t != 'نمطي' && t != 'نمطى');
      }

      return matchDate && matchCust && matchCat && matchType;
    }).toList();
  }

  // نافذة تعديل بيانات ومكونات الطلب
  void _openEditOrderModal(Map<String, dynamic> order) {
    final custNameCtrl = TextEditingController(text: order['customer_name']);
    final specsCtrl = TextEditingController(text: order['specs'] ?? '');
    String selectedOrderType = (order['order_type'] == 'أوردر' || order['order_type'] == 'اوردر')
        ? 'أوردر'
        : 'نمطي';
    DateTime deliveryDate =
        DateTime.tryParse(order['delivery_date'] ?? '') ?? DateTime.now();

    List comps = [];
    try {
      comps = jsonDecode(order['selected_components_json']);
    } catch (_) {}

    final List<Map<String, dynamic>> editableComps = comps.map((c) {
      final int q =
          (c['qty'] is int) ? c['qty'] : int.tryParse(c['qty'].toString()) ?? 1;
      return {
        'name': c['name'].toString(),
        'qty': q,
      };
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: AppTheme.modalSheetPadding(ctx),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'تعديل الطلب: طقم (${order['category_name']})',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryNavy),
                      ),
                    ),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: custNameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'اسم الزبون / العميل *',
                      prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Colors.black12),
                  ),
                  leading: const Icon(Icons.calendar_month,
                      color: AppTheme.primaryNavy),
                  title: const Text('موعد التسليم'),
                  subtitle: Text(
                    intl.DateFormat('yyyy-MM-dd').format(deliveryDate),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                        fontSize: 15),
                  ),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: deliveryDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setModalState(() => deliveryDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: specsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'المواصفات وملاحظات القماش والألوان',
                    prefixIcon: Icon(Icons.description),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setModalState(() => selectedOrderType = 'نمطي'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: selectedOrderType == 'نمطي' ? AppTheme.primaryNavy : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selectedOrderType == 'نمطي' ? AppTheme.primaryNavy : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selectedOrderType == 'نمطي' ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 16,
                                color: selectedOrderType == 'نمطي' ? AppTheme.royalGold : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'نمطي',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: selectedOrderType == 'نمطي' ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setModalState(() => selectedOrderType = 'أوردر'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: selectedOrderType == 'أوردر' ? AppTheme.primaryNavy : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selectedOrderType == 'أوردر' ? AppTheme.primaryNavy : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selectedOrderType == 'أوردر' ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 16,
                                color: selectedOrderType == 'أوردر' ? AppTheme.royalGold : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'أوردر',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: selectedOrderType == 'أوردر' ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(),
                const Text(
                  'القطع المطلوبة في هذا الطلب وأعدادها:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                ...editableComps.asMap().entries.map((entry) {
                  final comp = entry.value;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(comp['name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        // زر إنقاص
                        Material(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              if (comp['qty'] > 1) {
                                setModalState(() => comp['qty']--);
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(6.0),
                              child: Icon(Icons.remove,
                                  color: Colors.red, size: 20),
                            ),
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 36),
                          alignment: Alignment.center,
                          child: Text('${comp['qty']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 17)),
                        ),
                        // زر زيادة
                        Material(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              setModalState(() => comp['qty']++);
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(6.0),
                              child: Icon(Icons.add,
                                  color: Colors.green, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    foregroundColor: AppTheme.royalGold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    if (custNameCtrl.text.trim().isEmpty) {
                      AppNotification.showError(ctx, 'يرجى كتابة اسم العميل');
                      return;
                    }
                    final db = await DBHelper.instance.database;
                    await db.update(
                        'orders',
                        {
                          'customer_name': custNameCtrl.text.trim(),
                          'specs': specsCtrl.text.trim(),
                          'order_type': selectedOrderType,
                          'delivery_date': intl.DateFormat('yyyy-MM-dd')
                              .format(deliveryDate),
                          'selected_components_json': jsonEncode(editableComps),
                        },
                        where: 'id = ?',
                        whereArgs: [order['id']]);

                    AppEvents.instance.notifyAll();
                    if (mounted) {
                      Navigator.pop(ctx);
                      AppNotification.showSuccess(
                          context, 'تم تحديث بيانات الطلب بنجاح');
                    }
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('حفظ تعديلات الطلب',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndDeliverOrder(Map<String, dynamic> order) async {
    final db = await DBHelper.instance.database;

    List rawOrderComps = [];
    try {
      rawOrderComps = jsonDecode((order['selected_components_json'] ?? '[]').toString());
    } catch (_) {}

    final catRows = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [order['category_id']],
    );

    List rawCatComps = [];
    int oldCatStock = 0;
    if (catRows.isNotEmpty) {
      oldCatStock = (catRows.first['stock_qty'] as int?) ?? 0;
      try {
        rawCatComps = jsonDecode((catRows.first['components_json'] ?? '[]').toString());
      } catch (_) {}
    }

    final int orderSets = (order['sets_count'] as int?) ?? 1;
    final orderPieces = OrderDeliveryHelper.extractOrderPieces(
      rawOrderComps,
      rawCatComps,
      setsCount: orderSets,
    );

    final Map<String, int> selectedQty = {
      for (final p in orderPieces) (p['name'] as String): (p['qty'] as int),
    };
    final int totalAvailablePieces =
        orderPieces.fold<int>(0, (sum, p) => sum + ((p['qty'] as int?) ?? 0));

    bool isPartialMode = false;
    bool isSaving = false;

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final int currentDeliverCount = isPartialMode
              ? selectedQty.values.fold<int>(0, (sum, q) => sum + q)
              : totalAvailablePieces;

          final bool canSubmit = !isSaving &&
              (orderPieces.isEmpty || currentDeliverCount > 0);

          final bottomSafe = MediaQuery.of(ctx).viewPadding.bottom;

          return Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomSafe + 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. رأس مضغوط وواضح
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.local_shipping_rounded, color: Colors.green.shade700, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تسليم: ${order['customer_name']}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryNavy,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'طقم ${order['category_name']} • ${order['order_type']}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: const Icon(Icons.close),
                      onPressed: isSaving ? null : () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                if (orderPieces.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  // 2. التبديل السريع بين تسليم كامل أو تسليم قطع محددة
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: Text(
                              'تسليم كامل',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ),
                          selected: !isPartialMode,
                          selectedColor: AppTheme.primaryNavy,
                          labelStyle: TextStyle(
                            color: !isPartialMode ? AppTheme.royalGold : Colors.black87,
                          ),
                          showCheckmark: false,
                          onSelected: isSaving
                              ? null
                              : (_) {
                                  setModalState(() {
                                    isPartialMode = false;
                                    for (final p in orderPieces) {
                                      selectedQty[p['name'] as String] = p['qty'] as int;
                                    }
                                  });
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: Text(
                              'تسليم جزء / قطع محددة',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ),
                          selected: isPartialMode,
                          selectedColor: AppTheme.primaryNavy,
                          labelStyle: TextStyle(
                            color: isPartialMode ? AppTheme.royalGold : Colors.black87,
                          ),
                          showCheckmark: false,
                          onSelected: isSaving
                              ? null
                              : (_) => setModalState(() => isPartialMode = true),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),

                // 3. ملخص مختصر أو قائمة قطع مضغوطة بارتفاع محكوم حتى يبقى زر التسليم ظاهراً دائماً
                if (!isPartialMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      orderPieces.isNotEmpty
                          ? 'سيتم تسليم كامل الطلب ($totalAvailablePieces قطعة) وخصمها من رصيد المخزن ونقل الطلب إلى صفحة (تم التسليم).'
                          : 'سيتم تأكيد تسليم طقم (${order['category_name']}) بالكامل وخصمه من رصيد المخزن.',
                      style: TextStyle(fontSize: 13, color: Colors.green.shade900, height: 1.4),
                    ),
                  )
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'حدد القطع المسلمة الآن:',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: isSaving
                                ? null
                                : () {
                                    setModalState(() {
                                      for (final p in orderPieces) {
                                        selectedQty[p['name'] as String] = p['qty'] as int;
                                      }
                                    });
                                  },
                            child: const Text('تحديد الكل', style: TextStyle(fontSize: 12)),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: Colors.red.shade700,
                            ),
                            onPressed: isSaving
                                ? null
                                : () {
                                    setModalState(() {
                                      for (final p in orderPieces) {
                                        selectedQty[p['name'] as String] = 0;
                                      }
                                    });
                                  },
                            child: const Text('تصفير', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.34,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: orderPieces.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, idx) {
                        final p = orderPieces[idx];
                        final name = p['name'] as String;
                        final maxQ = p['qty'] as int;
                        final curQ = selectedQty[name] ?? 0;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: curQ > 0 ? Colors.green.withValues(alpha: 0.05) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: curQ > 0
                                  ? Colors.green.withValues(alpha: 0.35)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$name  (المتاح: $maxQ)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: curQ > 0 ? Colors.red.shade700 : Colors.grey,
                                  size: 22,
                                ),
                                onPressed: (!isSaving && curQ > 0)
                                    ? () => setModalState(() => selectedQty[name] = curQ - 1)
                                    : null,
                              ),
                              Container(
                                constraints: const BoxConstraints(minWidth: 28),
                                alignment: Alignment.center,
                                child: Text(
                                  '$curQ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: AppTheme.primaryNavy,
                                  ),
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: Icon(
                                  Icons.add_circle_outline,
                                  color: curQ < maxQ ? Colors.green.shade700 : Colors.grey,
                                  size: 22,
                                ),
                                onPressed: (!isSaving && curQ < maxQ)
                                    ? () => setModalState(() => selectedQty[name] = curQ + 1)
                                    : null,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // 4. شريط التأكيد السفلي الثابت (لا يختفي أبداً أسفل الشاشة)
                Row(
                  children: [
                    TextButton(
                      onPressed: isSaving ? null : () => Navigator.pop(ctx),
                      child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: !canSubmit
                            ? null
                            : () async {
                                setModalState(() => isSaving = true);
                                try {
                                  final Map<String, int> deliverMap = isPartialMode
                                      ? Map<String, int>.from(selectedQty)
                                      : {
                                          for (final p in orderPieces)
                                            (p['name'] as String): (p['qty'] as int),
                                        };

                                  final calc = OrderDeliveryHelper.computeDelivery(
                                    orderPieces: orderPieces,
                                    deliverQuantities: deliverMap,
                                    rawCategoryComps: rawCatComps,
                                    fallbackCategoryStock: oldCatStock,
                                  );

                                  final todayStr =
                                      intl.DateFormat('yyyy-MM-dd').format(DateTime.now());

                                  await db.transaction((txn) async {
                                    if (orderPieces.isEmpty || calc.isFullDelivery) {
                                      await txn.update(
                                        'orders',
                                        {'status': 'delivered'},
                                        where: 'id = ?',
                                        whereArgs: [order['id']],
                                      );
                                    } else {
                                      // 1) تحديث طلب الانتظار بالقطع المتبقية فقط
                                      await txn.update(
                                        'orders',
                                        {
                                          'selected_components_json':
                                              jsonEncode(calc.remainingComps),
                                          'sets_count': calc.remainingOrderSets,
                                        },
                                        where: 'id = ?',
                                        whereArgs: [order['id']],
                                      );

                                      // 2) تسجيل سجل للقطع المسلّمة في قائمة (تم التسليم)
                                      final oldSpecs =
                                          (order['specs'] ?? '').toString().trim();
                                      final partialSpecs = oldSpecs.isEmpty
                                          ? 'تسليم جزئي من الطلب'
                                          : '$oldSpecs (تسليم جزئي)';

                                      await txn.insert('orders', {
                                        'customer_id': order['customer_id'],
                                        'customer_name': order['customer_name'],
                                        'category_id': order['category_id'],
                                        'category_name': order['category_name'],
                                        'selected_components_json':
                                            jsonEncode(calc.deliveredComps),
                                        'specs': partialSpecs,
                                        'delivery_date': todayStr,
                                        'order_type': order['order_type'],
                                        'sets_count': 0,
                                        'status': 'delivered',
                                        'created_at': order['created_at'] ?? todayStr,
                                      });
                                    }

                                    if (catRows.isNotEmpty) {
                                      await txn.update(
                                        'categories',
                                        {
                                          'stock_qty': calc.newCategorySets,
                                          'components_json':
                                              jsonEncode(calc.updatedCategoryComps),
                                        },
                                        where: 'id = ?',
                                        whereArgs: [order['category_id']],
                                      );
                                    }
                                  });

                                  final String summaryPieces = calc.deliveredComps
                                      .map((c) => '${c['name']}: ${c['qty']}')
                                      .join('، ');
                                  final int setDelta = calc.newCategorySets - oldCatStock;

                                  await StockMovementHelper.logMovement(
                                    categoryId: order['category_id'],
                                    categoryName: order['category_name'],
                                    movementType: 'delivered_out',
                                    qtyChange: setDelta != 0
                                        ? setDelta
                                        : (calc.isFullDelivery ? -1 : 0),
                                    stockAfter: calc.newCategorySets,
                                    notes: calc.isFullDelivery
                                        ? 'تسليم أوردر للعميل: ${order['customer_name']} (أصبح رصيد الأطقم بالمخزن ${calc.newCategorySets})'
                                        : 'تسليم جزئي للعميل: ${order['customer_name']} [$summaryPieces] (المتبقي بالمخزن ${calc.newCategorySets} طقم)',
                                  );

                                  AppEvents.instance.notifyAll();
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    AppNotification.showSuccess(
                                      context,
                                      calc.isFullDelivery
                                          ? 'تم تسليم الطلب بالكامل وخصمه من المخزن بنجاح!'
                                          : 'تم تسليم ${calc.totalDeliveredPieces} قطعة وخصمها، والمتبقي (${calc.totalRemainingPieces} قطعة) ما زال بقائمة الانتظار.',
                                    );
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    setModalState(() => isSaving = false);
                                    AppNotification.showError(ctx, 'حدث خطأ أثناء التسليم');
                                  }
                                }
                              },
                        icon: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 19),
                        label: Text(
                          isPartialMode && orderPieces.isNotEmpty
                              ? 'تسليم ($currentDeliverCount) قطعة الآن'
                              : 'تأكيد التسليم والخصم',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredOrders;

    final uniqueCustomers = _orders
        .map((o) => (o['customer_name'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final uniqueCategories = _orders
        .map((o) => (o['category_name'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final customerValue = uniqueCustomers.contains(_filterCustomer) ? _filterCustomer : '';
    final categoryValue = uniqueCategories.contains(_filterCategory) ? _filterCategory : '';

    int standardCount = 0;
    int customCount = 0;
    for (final o in _orders) {
      final t = (o['order_type'] ?? '').toString().trim();
      if (t == 'نمطي' || t == 'نمطى') {
        standardCount++;
      } else {
        customCount++;
      }
    }

    final bool hasFilter = _filterCustomer.isNotEmpty ||
        _filterCategory.isNotEmpty ||
        _filterDate != null ||
        _filterOrderType != 'all';

    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitleWithLogo(title: 'قائمة الانتظار (مرتبطة بموعد التسليم)'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // 1. فلتر نوع الطلب (الكل / نمطي / أوردر)
                Row(
                  children: [
                    _TypeFilterChip(
                      label: 'الكل (${_orders.length})',
                      icon: Icons.all_inbox_rounded,
                      isSelected: _filterOrderType == 'all',
                      onTap: () => setState(() => _filterOrderType = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _TypeFilterChip(
                      label: 'نمطي ($standardCount)',
                      icon: Icons.style_rounded,
                      isSelected: _filterOrderType == 'نمطي',
                      onTap: () => setState(() => _filterOrderType = 'نمطي'),
                    ),
                    const SizedBox(width: 8),
                    _TypeFilterChip(
                      label: 'أوردر ($customCount)',
                      icon: Icons.shopping_bag_outlined,
                      isSelected: _filterOrderType == 'أوردر',
                      onTap: () => setState(() => _filterOrderType = 'أوردر'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    // دروب ليست فلتر اسم الزبون المسجل بقائمة الانتظار
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey("cust_$customerValue"),
                        initialValue: customerValue,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'اسم الزبون',
                          prefixIcon: const Icon(Icons.person_pin_rounded, color: AppTheme.primaryNavy, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('جميع العملاء (الكل)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          ...uniqueCustomers.map(
                            (name) => DropdownMenuItem<String>(
                              value: name,
                              child: Text(name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _filterCustomer = v ?? ''),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // دروب ليست فلتر اسم الطقم المسجل بقائمة الانتظار
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey("cat_$categoryValue"),
                        initialValue: categoryValue,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'اسم الطقم',
                          prefixIcon: const Icon(Icons.weekend_rounded, color: AppTheme.primaryNavy, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('جميع الأطقم (الكل)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          ...uniqueCategories.map(
                            (cat) => DropdownMenuItem<String>(
                              value: cat,
                              child: Text(cat, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _filterCategory = v ?? ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_filterDate == null
                            ? 'فلتر بتاريخ التسليم (الكل)'
                            : 'أوردرات يوم: $_filterDate'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() => _filterDate =
                                intl.DateFormat('yyyy-MM-dd').format(picked));
                          }
                        },
                      ),
                    ),
                    if (hasFilter) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        ),
                        onPressed: () {
                          setState(() {
                            _filterCustomer = '';
                            _filterCategory = '';
                            _filterDate = null;
                            _filterOrderType = 'all';
                          });
                        },
                        icon: const Icon(Icons.filter_alt_off, size: 16),
                        label: const Text('مسح الفلاتر', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadOrders,
              child: list.isEmpty
                  ? const RefreshableEmptyView(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'لا توجد أوردرات مطابقة في قائمة الانتظار.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(
                          left: 12, right: 12, top: 12, bottom: 80),
                      itemCount: list.length,
                      itemBuilder: (ctx, i) {
                        final order = list[i];
                        final int orderId = (order['id'] as int?) ?? i;
                        final bool isExpanded = _expandedOrderIds.contains(orderId);
                        return OrderCard(
                          order: order,
                          collapsible: true,
                          isExpanded: isExpanded,
                          onToggleExpand: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedOrderIds.remove(orderId);
                              } else {
                                _expandedOrderIds.add(orderId);
                              }
                            });
                          },
                          onEditPressed: () => _openEditOrderModal(order),
                          onDeliverPressed: () => _confirmAndDeliverOrder(order),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeFilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryNavy : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primaryNavy : Colors.grey.shade300,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? AppTheme.royalGold : Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
