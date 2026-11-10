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
          o['customer_name'].toString().contains(_filterCustomer);
      final matchCat = _filterCategory.isEmpty ||
          o['category_name'].toString().contains(_filterCategory);
      return matchDate && matchCust && matchCat;
    }).toList();
  }

  // نافذة تعديل بيانات ومكونات الطلب
  void _openEditOrderModal(Map<String, dynamic> order) {
    final custNameCtrl = TextEditingController(text: order['customer_name']);
    final specsCtrl = TextEditingController(text: order['specs'] ?? '');
    final typeCtrl =
        TextEditingController(text: order['order_type'] ?? 'مودرن');
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
                TextField(
                  controller: typeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'النوع / الستايل',
                    prefixIcon: Icon(Icons.style),
                  ),
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
                          'order_type': typeCtrl.text.trim().isEmpty
                              ? 'مودرن'
                              : typeCtrl.text.trim(),
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
              await db.transaction((txn) async {
                await txn.update('orders', {'status': 'delivered'},
                    where: 'id = ?', whereArgs: [order['id']]);
                await txn.rawUpdate(
                    'UPDATE categories SET stock_qty = stock_qty - 1 WHERE id = ?',
                    [order['category_id']]);
              });
              final catRows = await db.query('categories', where: 'id = ?', whereArgs: [order['category_id']]);
              final currentStock = catRows.isNotEmpty ? (catRows.first['stock_qty'] as int) : 0;
              await StockMovementHelper.logMovement(
                categoryId: order['category_id'],
                categoryName: order['category_name'],
                movementType: 'delivered_out',
                qtyChange: -1,
                stockAfter: currentStock,
                notes: 'تسليم أوردر للعميل: ${order['customer_name']}',
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                            hintText: 'فلتر باسم الزبون...',
                            prefixIcon: Icon(Icons.person_search)),
                        onChanged: (v) =>
                            setState(() => _filterCustomer = v.trim()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                            hintText: 'فلتر باسم الطقم...',
                            prefixIcon: Icon(Icons.search)),
                        onChanged: (v) =>
                            setState(() => _filterCategory = v.trim()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
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
                    if (_filterDate != null)
                      IconButton(
                        tooltip: 'إلغاء فلتر التاريخ',
                        icon: const Icon(Icons.clear, color: Colors.red),
                        onPressed: () => setState(() => _filterDate = null),
                      ),
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
