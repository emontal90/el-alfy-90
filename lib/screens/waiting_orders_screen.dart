import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../components/app_logo.dart';
import '../components/distinctive_refresh_button.dart';
import '../components/order_card.dart';
import '../core/app_events.dart';
import '../core/app_notification.dart';
import '../core/app_theme.dart';
import '../core/db_helper.dart';
import '../core/stock_movement_helper.dart';

class WaitingOrdersScreen extends StatefulWidget {
  const WaitingOrdersScreen({super.key});
  @override
  State<WaitingOrdersScreen> createState() => _WaitingOrdersScreenState();
}

class _WaitingOrdersScreenState extends State<WaitingOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 16,
            right: 16,
            top: 20,
          ),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد تسليم الأوردر'),
        content: Text(
          'هل أنت متأكد من تسليم طقم (${order['category_name']}) للعميل (${order['customer_name']})؟\n\nسيتم الآن خصم الطقم من رصيد المخزن ونقل الطلب لصفحة (تم التسليم).',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white),
            onPressed: () async {
              final db = await DBHelper.instance.database;

              // 1. جلب مكونات الطلب المطلوب تسليمه ومكونات المخزن الحالية للصنف
              List orderComps = [];
              try {
                orderComps = jsonDecode(order['selected_components_json'] ?? '[]');
              } catch (_) {}

              final catRows = await db.query('categories', where: 'id = ?', whereArgs: [order['category_id']]);
              int newCalculatedSets = 0;
              List validCatComps = [];

              if (catRows.isNotEmpty) {
                final catRow = catRows.first;
                try {
                  validCatComps = jsonDecode((catRow['components_json'] ?? '[]').toString());
                } catch (_) {}

                if (orderComps.isNotEmpty) {
                  // خصم القطع المحددة في هذا الأوردر بالتحديد من رصيد مكونات المخزن
                  for (final oc in orderComps) {
                    final String oName = (oc['name'] ?? '').toString().trim();
                    final int oQty = (oc['qty'] is int)
                        ? oc['qty'] as int
                        : (int.tryParse(oc['qty']?.toString() ?? '1') ?? 1);

                    for (final cc in validCatComps) {
                      if ((cc['name'] ?? '').toString().trim() == oName) {
                        final int currentQ = (cc['qty'] as int?) ?? 0;
                        cc['qty'] = (currentQ - oQty) >= 0 ? (currentQ - oQty) : 0;
                        break;
                      }
                    }
                  }
                } else {
                  // إذا لم تكن القطع مسرودة، خصم طقم كامل بنسبه التأسيسية
                  for (final cc in validCatComps) {
                    final int bQty = (cc['base_qty'] as int?) ?? 1;
                    final int currentQ = (cc['qty'] as int?) ?? 0;
                    cc['qty'] = (currentQ - bQty) >= 0 ? (currentQ - bQty) : 0;
                  }
                }

                // حساب الأطقم الكاملة المتبقية بعد الخصم
                if (validCatComps.isNotEmpty) {
                  newCalculatedSets = validCatComps.map<int>((c) {
                    final q = (c['qty'] is int) ? c['qty'] as int : (int.tryParse(c['qty']?.toString() ?? '0') ?? 0);
                    final b = (c['base_qty'] is int) ? c['base_qty'] as int : (int.tryParse(c['base_qty']?.toString() ?? '1') ?? 1);
                    return q ~/ (b > 0 ? b : 1);
                  }).reduce(math.min);
                }
              }

              await db.transaction((txn) async {
                await txn.update('orders', {'status': 'delivered'},
                    where: 'id = ?', whereArgs: [order['id']]);
                if (catRows.isNotEmpty) {
                  await txn.update(
                    'categories',
                    {
                      'stock_qty': newCalculatedSets,
                      'components_json': jsonEncode(validCatComps),
                    },
                    where: 'id = ?',
                    whereArgs: [order['category_id']],
                  );
                }
              });

              await StockMovementHelper.logMovement(
                categoryId: order['category_id'],
                categoryName: order['category_name'],
                movementType: 'delivered_out',
                qtyChange: -1,
                stockAfter: newCalculatedSets,
                notes: 'تسليم أوردر للعميل: ${order['customer_name']} (أصبح رصيد الأطقم بالمخزن $newCalculatedSets)',
              );
              AppEvents.instance.notifyAll();
              if (mounted) {
                Navigator.pop(ctx);
                AppNotification.showSuccess(
                    context, 'تم تسليم الأوردر وخصمه من رصيد المخزن بنجاح!');
              }
            },
            child: const Text('تأكيد التسليم والخصم'),
          ),
        ],
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
        title: const Row(
          children: [
            AppLogo(size: 34),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'قائمة الانتظار (مرتبطة بموعد التسليم)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: const [
          DistinctiveRefreshButton(),
        ],
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
            child: list.isEmpty
                ? const Center(
                    child: Text('لا توجد أوردرات مطابقة في قائمة الانتظار.'))
                : ListView.builder(
                    padding: const EdgeInsets.only(
                        left: 12, right: 12, top: 12, bottom: 80),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) => OrderCard(
                      order: list[i],
                      onEditPressed: () => _openEditOrderModal(list[i]),
                      onDeliverPressed: () => _confirmAndDeliverOrder(list[i]),
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
