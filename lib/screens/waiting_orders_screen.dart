import 'dart:convert';
import 'dart:math' as math;
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
  Map<int, List<dynamic>> _categoryCompsById = {};
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
    final cats = await db.query('categories', columns: ['id', 'components_json']);
    final Map<int, List<dynamic>> compsMap = {};
    for (final c in cats) {
      final cid = c['id'] as int?;
      if (cid == null) continue;
      try {
        final decoded = jsonDecode((c['components_json'] ?? '[]').toString());
        if (decoded is List) {
          compsMap[cid] = decoded;
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _orders = data;
        _categoryCompsById = compsMap;
      });
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
  Future<void> _openEditOrderModal(Map<String, dynamic> order) async {
    final db = await DBHelper.instance.database;
    final categories = await db.query('categories', orderBy: 'id DESC');
    if (!mounted) return;

    final custNameCtrl = TextEditingController(text: order['customer_name']);
    final specsCtrl = TextEditingController(text: order['specs'] ?? '');
    String selectedOrderType = (order['order_type'] == 'أوردر' || order['order_type'] == 'اوردر')
        ? 'أوردر'
        : 'نمطي';
    DateTime deliveryDate =
        DateTime.tryParse(order['delivery_date'] ?? '') ?? DateTime.now();

    int selectedCategoryId = (order['category_id'] as int?) ?? 0;
    String selectedCategoryName = (order['category_name'] ?? '').toString();
    final int initialOrderSets = (order['sets_count'] as int?) ?? 1;

    List<dynamic> findCatComps(int catId) {
      for (final cat in categories) {
        if (cat['id'] == catId) {
          try {
            final decoded = jsonDecode((cat['components_json'] ?? '[]').toString());
            if (decoded is List) return decoded;
          } catch (_) {}
        }
      }
      return const [];
    }

    List comps = [];
    try {
      comps = jsonDecode((order['selected_components_json'] ?? '[]').toString());
    } catch (_) {}

    final initialCatComps = findCatComps(selectedCategoryId);
    List<Map<String, dynamic>> editableComps = OrderDeliveryHelper.extractOrderPieces(
      comps,
      initialCatComps,
      setsCount: initialOrderSets,
    );

    int? secondaryCategoryId;
    bool addFromOtherCategory = editableComps.any((c) => c['source_category_id'] != null);
    if (addFromOtherCategory) {
      final firstSec = editableComps.firstWhere((c) => c['source_category_id'] != null);
      secondaryCategoryId = firstSec['source_category_id'] as int?;
    }

    List<Map<String, dynamic>> parseCategoryPieces(Map<String, dynamic> cat) {
      List decoded = [];
      try {
        final raw = jsonDecode((cat['components_json'] ?? '[]').toString());
        if (raw is List) decoded = raw;
      } catch (_) {}
      return decoded.whereType<Map>().map((e) {
        final int stockQty = (e['qty'] is int)
            ? e['qty'] as int
            : (int.tryParse(e['qty']?.toString() ?? '0') ?? 0);
        return {
          'name': (e['name'] ?? '').toString(),
          'stock_qty': stockQty,
        };
      }).where((e) => (e['name'] as String).isNotEmpty).toList();
    }

    int getSecondaryPieceQty(int secCatId, String pieceName) {
      for (final c in editableComps) {
        if (c['source_category_id'] == secCatId &&
            c['source_piece_name'] == pieceName) {
          return (c['qty'] as int?) ?? 0;
        }
      }
      return 0;
    }

    void setSecondaryPieceQty(Map<String, dynamic> secCat, String pieceName, int newQty) {
      final int secCatId = secCat['id'] as int;
      final String secCatName = (secCat['name'] ?? '').toString();
      final existingIdx = editableComps.indexWhere(
        (c) => c['source_category_id'] == secCatId && c['source_piece_name'] == pieceName,
      );
      if (newQty <= 0) {
        if (existingIdx != -1) {
          editableComps.removeAt(existingIdx);
        }
      } else if (existingIdx != -1) {
        editableComps[existingIdx]['qty'] = newQty;
      } else {
        editableComps.add({
          'name': '$pieceName ($secCatName)',
          'source_piece_name': pieceName,
          'source_category_id': secCatId,
          'source_category_name': secCatName,
          'base_qty': 0,
          'qty': newQty,
          'original_qty': 0,
          'selected': true,
          'is_custom': true,
        });
      }
    }

    final bool existingCatPresent =
        categories.any((c) => c['id'] == selectedCategoryId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
        final otherCategories = categories.where((c) => c['id'] != selectedCategoryId).toList();
        final secondaryCategory = otherCategories.cast<Map<String, dynamic>?>().firstWhere(
              (c) => c?['id'] == secondaryCategoryId,
              orElse: () => null,
            );

        return Padding(
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
                        'تعديل الطلب: طقم ($selectedCategoryName)',
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
                if (categories.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    initialValue: existingCatPresent
                        ? selectedCategoryId
                        : (selectedCategoryId > 0 ? selectedCategoryId : null),
                    decoration: const InputDecoration(
                      labelText: 'الصنف / الموديل *',
                      prefixIcon: Icon(Icons.weekend_rounded),
                    ),
                    isExpanded: true,
                    items: [
                      if (!existingCatPresent && selectedCategoryId > 0)
                        DropdownMenuItem<int>(
                          value: selectedCategoryId,
                          child: Text('$selectedCategoryName (محذوف من الأصناف)'),
                        ),
                      ...categories.map((cat) {
                        return DropdownMenuItem<int>(
                          value: cat['id'] as int,
                          child: Text((cat['name'] ?? '').toString()),
                        );
                      }),
                    ],
                    onChanged: (newCatId) {
                      if (newCatId == null || newCatId == selectedCategoryId) return;
                      final matched = categories.cast<Map<String, dynamic>?>().firstWhere(
                            (c) => c?['id'] == newCatId,
                            orElse: () => null,
                          );
                      if (matched == null) return;
                      final newCatComps = findCatComps(newCatId);
                      final int targetSets = initialOrderSets > 0 ? initialOrderSets : 1;
                      setModalState(() {
                        selectedCategoryId = newCatId;
                        selectedCategoryName = (matched['name'] ?? '').toString();
                        final secPieces = editableComps.where((c) => c['source_category_id'] != null).toList();
                        editableComps = [
                          ...OrderDeliveryHelper.extractOrderPieces(
                            const [],
                            newCatComps,
                            setsCount: targetSets,
                          ),
                          ...secPieces,
                        ];
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
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
                  final index = entry.key;
                  final comp = entry.value;
                  final bool isFromOtherCat = comp['source_category_id'] != null;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isFromOtherCat ? const Color(0xFFF0FDFA) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isFromOtherCat ? const Color(0xFF99F6E4) : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comp['name'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              if (isFromOtherCat)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFCCFBF1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF5EEAD4)),
                                  ),
                                  child: Text(
                                    'من طقم: ${comp['source_category_name']}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F766E),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // زر إنقاص
                        Material(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              if (comp['qty'] > 0) {
                                setModalState(() => comp['qty']--);
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(6.0),
                              child: Icon(Icons.remove, color: Colors.red, size: 20),
                            ),
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 36),
                          alignment: Alignment.center,
                          child: Text(
                            '${comp['qty']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                          ),
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
                              child: Icon(Icons.add, color: Colors.green, size: 20),
                            ),
                          ),
                        ),
                        if (isFromOtherCat) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            tooltip: 'إزالة هذه القطعة',
                            onPressed: () {
                              setModalState(() {
                                editableComps.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),

                // فاصل أنيق وبسيط قبل قسم إضافة قطع من طقم آخر
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: Colors.teal.shade200, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.style_outlined, size: 16, color: Colors.teal.shade700),
                            const SizedBox(width: 5),
                            Text(
                              'قطع إضافية من أطقم أخرى',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.teal.shade200, thickness: 1)),
                    ],
                  ),
                ),

                // اختيار إضافة قطع فردية من طقم آخر بخلفية مميزة
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: addFromOtherCategory
                          ? [const Color(0xFFE6FFFA), const Color(0xFFCCFBF1)]
                          : [const Color(0xFFF0FDFA), const Color(0xFFF8FAFC)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: addFromOtherCategory
                          ? const Color(0xFF0D9488)
                          : const Color(0xFF99F6E4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D9488).withValues(alpha: addFromOtherCategory ? 0.12 : 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CheckboxListTile(
                        value: addFromOtherCategory,
                        activeColor: const Color(0xFF0F766E),
                        checkColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        title: const Row(
                          children: [
                            Icon(Icons.add_shopping_cart_rounded, size: 20, color: Color(0xFF0F766E)),
                            SizedBox(width: 8),
                            Text(
                              'إضافة قطع من طقم آخر',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),
                        subtitle: const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'مثل إضافة كنبة فرداني من صنف آخر ليتم خصمها من مخزونه عند التسليم',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF115E59)),
                          ),
                        ),
                        onChanged: (checked) {
                          setModalState(() {
                            addFromOtherCategory = checked ?? false;
                            if (!addFromOtherCategory) {
                              secondaryCategoryId = null;
                              editableComps.removeWhere(
                                (c) => c['source_category_id'] != null,
                              );
                            }
                          });
                        },
                      ),
                      if (addFromOtherCategory)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: otherCategories.isEmpty
                              ? const Text(
                                  'لا توجد أصناف أخرى مسجلة حالياً.',
                                  style: TextStyle(color: Colors.grey, fontSize: 12.5),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    DropdownButtonFormField<int>(
                                      key: ValueKey('sec_cat_${secondaryCategoryId ?? 'none'}'),
                                      initialValue: secondaryCategoryId,
                                      decoration: const InputDecoration(
                                        labelText: 'اختر الطقم الآخر *',
                                        prefixIcon: Icon(Icons.weekend_outlined),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      isExpanded: true,
                                      items: otherCategories.map((c) {
                                        return DropdownMenuItem<int>(
                                          value: c['id'] as int,
                                          child: Text('${c['name']} (رصيد: ${c['stock_qty']})'),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setModalState(() => secondaryCategoryId = val);
                                      },
                                    ),
                                    if (secondaryCategory != null) ...[
                                      const SizedBox(height: 10),
                                      const Text(
                                        'اختر القطع المطلوبة من هذا الطقم:',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryNavy,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ...parseCategoryPieces(secondaryCategory).map((p) {
                                        final String pName = p['name'] as String;
                                        final int stockQ = p['stock_qty'] as int;
                                        final int secId = secondaryCategory['id'] as int;
                                        final int curQ = getSecondaryPieceQty(secId, pName);

                                        return Container(
                                          margin: const EdgeInsets.symmetric(vertical: 3),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: curQ > 0 ? Colors.white : Colors.white.withValues(alpha: 0.7),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: curQ > 0 ? Colors.teal.shade400 : Colors.grey.shade300,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      pName,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13.5,
                                                      ),
                                                    ),
                                                    Text(
                                                      'متاح بالمخزن: $stockQ قطعة',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                    ),
                                                  ],
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
                                                onPressed: curQ > 0
                                                    ? () => setModalState(() => setSecondaryPieceQty(secondaryCategory, pName, curQ - 1))
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
                                                  color: Colors.green.shade700,
                                                  size: 22,
                                                ),
                                                onPressed: () => setModalState(() => setSecondaryPieceQty(secondaryCategory, pName, curQ + 1)),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                        ),
                    ],
                  ),
                ),
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
                    final totalPieces = editableComps.fold<int>(0, (sum, c) => sum + ((c['qty'] as int?) ?? 0));
                    if (totalPieces <= 0) {
                      AppNotification.showError(ctx, 'يرجى تحديد قطعة واحدة على الأقل في الطلب');
                      return;
                    }
                    final selectedCatComps = findCatComps(selectedCategoryId);
                    final updatedSummary = OrderDeliveryHelper.summarizeOrder(
                      orderComps: editableComps,
                      rawCategoryComps: selectedCatComps,
                      fallbackSetsCount: initialOrderSets,
                    );
                    await db.update(
                        'orders',
                        {
                          'customer_name': custNameCtrl.text.trim(),
                          'category_id': selectedCategoryId,
                          'category_name': selectedCategoryName,
                          'specs': specsCtrl.text.trim(),
                          'order_type': selectedOrderType,
                          'delivery_date': intl.DateFormat('yyyy-MM-dd')
                              .format(deliveryDate),
                          'selected_components_json': jsonEncode(editableComps),
                          'sets_count': updatedSummary.sets,
                        },
                        where: 'id = ?',
                        whereArgs: [order['id']]);

                    AppEvents.instance.notifyAll();
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
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
        );
      },
    ),
  );
}

  Future<void> _confirmCancelOrder(Map<String, dynamic> order) async {
    final custName = (order['customer_name'] ?? '').toString();
    final catName = (order['category_name'] ?? '').toString();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('تأكيد إلغاء الطلب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من إلغاء وحذف طلب العميل "$custName" لطقم "$catName" من قائمة الانتظار؟',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('تراجع', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('تأكيد إلغاء الطلب'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = await DBHelper.instance.database;
      await db.delete('orders', where: 'id = ?', whereArgs: [order['id']]);
      AppEvents.instance.notifyAll();
      if (mounted) {
        AppNotification.showSuccess(context, 'تم إلغاء الطلب بنجاح');
      }
    }
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
    final orderSummary = OrderDeliveryHelper.summarizeOrder(
      orderComps: orderPieces,
      rawCategoryComps: rawCatComps,
      fallbackSetsCount: orderSets,
    );
    final int maxOrderSets = orderSummary.sets;
    final int totalAvailablePieces = orderSummary.totalPieces;

    int deliverSets = 0;
    final Map<String, int> extraQty = {
      for (final p in orderPieces) (p['name'] as String): 0,
    };

    void clampExtrasToRemainingSets() {
      for (final p in orderPieces) {
        final name = p['name'] as String;
        final maxQ = p['qty'] as int;
        final baseQ = (p['base_qty'] as int?) ?? 0;
        final maxExtra = math.max(0, maxQ - deliverSets * baseQ);
        if ((extraQty[name] ?? 0) > maxExtra) {
          extraQty[name] = maxExtra;
        }
      }
    }

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
          final Map<String, int> partialDeliverMap = isPartialMode
              ? OrderDeliveryHelper.buildDeliverQuantities(
                  orderPieces: orderPieces,
                  deliverSets: deliverSets,
                  extraPieceQuantities: extraQty,
                )
              : {
                  for (final p in orderPieces) (p['name'] as String): (p['qty'] as int),
                };

          final livePreview = OrderDeliveryHelper.computeDelivery(
            orderPieces: orderPieces,
            deliverQuantities: partialDeliverMap,
            rawCategoryComps: rawCatComps,
            fallbackCategoryStock: oldCatStock,
            primaryCategoryId: order['category_id'] as int?,
          );

          final int currentDeliverCount = livePreview.totalDeliveredPieces;
          final bool canSubmit = !isSaving &&
              (orderPieces.isEmpty || currentDeliverCount > 0);

          final String deliveredLabel = OrderSetSummary(
            sets: livePreview.deliveredSets,
            individualPieces: livePreview.deliveredIndividualPieces,
            totalPieces: livePreview.totalDeliveredPieces,
          ).toOrangeBadgeLabel() ?? '0';

          final String remainingLabel = OrderSetSummary(
            sets: livePreview.remainingOrderSets,
            individualPieces: livePreview.remainingIndividualPieces,
            totalPieces: livePreview.totalRemainingPieces,
          ).toOrangeBadgeLabel() ?? 'لا شيء';

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
                              : (_) => setModalState(() {
                                    if (!isPartialMode) {
                                      deliverSets = 0;
                                      for (final p in orderPieces) {
                                        extraQty[p['name'] as String] = 0;
                                      }
                                    }
                                    isPartialMode = true;
                                  }),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),

                // 3. ملخص مختصر أو اختيار عدد الأطقم + القطع الفردية بارتفاع محكوم
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
                  if (maxOrderSets > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: deliverSets > 0
                              ? AppTheme.primaryNavy
                              : AppTheme.primaryNavy.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.layers_rounded, size: 19, color: AppTheme.primaryNavy),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'تسليم أطقم كاملة:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.primaryNavy,
                                  ),
                                ),
                                Text(
                                  'المتاح بالطلب: $maxOrderSets طقم',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: Icon(
                              Icons.remove_circle_outline,
                              color: deliverSets > 0 ? Colors.red.shade700 : Colors.grey,
                              size: 23,
                            ),
                            onPressed: (!isSaving && deliverSets > 0)
                                ? () => setModalState(() {
                                      deliverSets--;
                                      clampExtrasToRemainingSets();
                                    })
                                : null,
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 36),
                            alignment: Alignment.center,
                            child: Text(
                              '$deliverSets طقم',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: Icon(
                              Icons.add_circle_outline,
                              color: deliverSets < maxOrderSets ? Colors.green.shade700 : Colors.grey,
                              size: 23,
                            ),
                            onPressed: (!isSaving && deliverSets < maxOrderSets)
                                ? () => setModalState(() {
                                      deliverSets++;
                                      clampExtrasToRemainingSets();
                                    })
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        maxOrderSets > 0
                            ? 'قطع فردية إضافية (تُخصم من المتبقي):'
                            : 'حدد القطع المسلمة الآن:',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                                      deliverSets = maxOrderSets;
                                      for (final p in orderPieces) {
                                        final name = p['name'] as String;
                                        final maxQ = p['qty'] as int;
                                        final baseQ = (p['base_qty'] as int?) ?? 0;
                                        extraQty[name] = math.max(0, maxQ - deliverSets * baseQ);
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
                                      deliverSets = 0;
                                      for (final p in orderPieces) {
                                        extraQty[p['name'] as String] = 0;
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
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.28,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: orderPieces.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, idx) {
                        final p = orderPieces[idx];
                        final name = p['name'] as String;
                        final maxQ = p['qty'] as int;
                        final baseQ = (p['base_qty'] as int?) ?? 0;
                        final fromSets = deliverSets * baseQ;
                        final remainingForExtra = math.max(0, maxQ - fromSets);
                        final curExtra = (extraQty[name] ?? 0).clamp(0, remainingForExtra);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (curExtra > 0 || fromSets > 0)
                                ? Colors.green.withValues(alpha: 0.05)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (curExtra > 0 || fromSets > 0)
                                  ? Colors.green.withValues(alpha: 0.35)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$name  (المتبقي: $remainingForExtra)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (fromSets > 0)
                                      Text(
                                        'ضمن الأطقم المحددة: $fromSets قطعة',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: Colors.green.shade800,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: curExtra > 0 ? Colors.red.shade700 : Colors.grey,
                                  size: 22,
                                ),
                                onPressed: (!isSaving && curExtra > 0)
                                    ? () => setModalState(() => extraQty[name] = curExtra - 1)
                                    : null,
                              ),
                              Container(
                                constraints: const BoxConstraints(minWidth: 28),
                                alignment: Alignment.center,
                                child: Text(
                                  '$curExtra',
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
                                  color: curExtra < remainingForExtra ? Colors.green.shade700 : Colors.grey,
                                  size: 22,
                                ),
                                onPressed: (!isSaving && curExtra < remainingForExtra)
                                    ? () => setModalState(() => extraQty[name] = curExtra + 1)
                                    : null,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      'المسلّم الآن: $deliveredLabel  |  المتبقي بالانتظار: $remainingLabel',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
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
                                  final Map<String, int> deliverMap = partialDeliverMap;

                                  final int? primaryCatId = order['category_id'] as int?;
                                  final calc = OrderDeliveryHelper.computeDelivery(
                                    orderPieces: orderPieces,
                                    deliverQuantities: deliverMap,
                                    rawCategoryComps: rawCatComps,
                                    fallbackCategoryStock: oldCatStock,
                                    primaryCategoryId: primaryCatId,
                                  );

                                  final todayStr =
                                      intl.DateFormat('yyyy-MM-dd').format(DateTime.now());
                                  List<SecondaryCategoryStockUpdate> secondaryUpdates = const [];

                                  await db.transaction((txn) async {
                                    if (orderPieces.isEmpty || calc.isFullDelivery) {
                                      await txn.update(
                                        'orders',
                                        {'status': 'delivered'},
                                        where: 'id = ?',
                                        whereArgs: [order['id']],
                                      );
                                    } else {
                                      // 1) تحديث طلب الانتظار بالقطع المتبقية وعدد الأطقم الكاملة المتبقي
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

                                      // 2) تسجيل سجل للقطع والأطقم المسلّمة في قائمة (تم التسليم)
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
                                        'sets_count': calc.deliveredSets,
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

                                    // 3) خصم القطع المضافة من أطقم أخرى من مخزون تلك الأطقم
                                    final secondaryIds = calc.deliveredComps
                                        .map((c) => c['source_category_id'] as int?)
                                        .whereType<int>()
                                        .where((id) => id != primaryCatId)
                                        .toSet()
                                        .toList();

                                    if (secondaryIds.isNotEmpty) {
                                      final Map<int, Map<String, dynamic>> secCatsById = {};
                                      for (final secId in secondaryIds) {
                                        final rows = await txn.query(
                                          'categories',
                                          where: 'id = ?',
                                          whereArgs: [secId],
                                        );
                                        if (rows.isNotEmpty) {
                                          secCatsById[secId] = rows.first;
                                        }
                                      }
                                      secondaryUpdates =
                                          OrderDeliveryHelper.computeSecondaryCategoryStockUpdates(
                                        deliveredComps: calc.deliveredComps,
                                        categoriesById: secCatsById,
                                        primaryCategoryId: primaryCatId,
                                      );
                                      for (final upd in secondaryUpdates) {
                                        await txn.update(
                                          'categories',
                                          {
                                            'stock_qty': upd.newStockSets,
                                            'components_json': jsonEncode(upd.updatedComps),
                                          },
                                          where: 'id = ?',
                                          whereArgs: [upd.categoryId],
                                        );
                                      }
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

                                  for (final upd in secondaryUpdates) {
                                    final secSummary = upd.deductedPieces
                                        .map((p) => '${p['name']}: ${p['qty']}')
                                        .join('، ');
                                    final int secDelta = upd.newStockSets - upd.oldStockSets;
                                    await StockMovementHelper.logMovement(
                                      categoryId: upd.categoryId,
                                      categoryName: upd.categoryName,
                                      movementType: 'delivered_out',
                                      qtyChange: secDelta,
                                      stockAfter: upd.newStockSets,
                                      notes:
                                          'تسليم قطع فردية ضمن طلب العميل: ${order['customer_name']} [$secSummary] (المتبقي بالمخزن ${upd.newStockSets} طقم)',
                                    );
                                  }

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
                          categoryComponents: _categoryCompsById[order['category_id']],
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
                          onDeletePressed: () => _confirmCancelOrder(order),
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
