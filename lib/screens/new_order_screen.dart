import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../components/app_logo.dart';
import '../core/app_events.dart';
import '../core/app_notification.dart';
import '../core/app_theme.dart';
import '../core/db_helper.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});
  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _categories = [];

  int? _selectedCustomerId;
  int? _selectedCategoryId;
  int _orderSetsCount = 1;
  List<Map<String, dynamic>> _editableComponents = [];

  Map<String, dynamic>? get _selectedCustomer {
    try {
      return _customers.firstWhere((c) => c['id'] == _selectedCustomerId);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? get _selectedCategory {
    try {
      return _categories.firstWhere((c) => c['id'] == _selectedCategoryId);
    } catch (_) {
      return null;
    }
  }

  final _specsCtrl = TextEditingController();
  String _orderType = 'نمطي';
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final db = await DBHelper.instance.database;
    final custs = await db.query('customers', orderBy: 'id DESC');
    final cats = await db.query('categories', orderBy: 'id DESC');
    setState(() {
      _customers = custs;
      _categories = cats;
    });
  }

  void _loadComponentsFromCategory(Map<String, dynamic> cat) {
    List decoded = [];
    try {
      decoded = jsonDecode(cat['components_json']);
    } catch (_) {}
    _orderSetsCount = 1;
    setState(() {
      _editableComponents = decoded.map((e) {
        final int baseQty = (e['base_qty'] is int)
            ? e['base_qty']
            : int.tryParse(e['base_qty']?.toString() ?? '') ??
                ((e['qty'] is int) ? e['qty'] : int.tryParse(e['qty']?.toString() ?? '') ?? 1);
        final int finalBase = baseQty > 0 ? baseQty : 1;
        return {
          'name': e['name'].toString(),
          'base_qty': finalBase,
          'qty': finalBase * _orderSetsCount,
          'original_qty': finalBase,
          'selected': true,
          'is_custom': false,
        };
      }).toList();
    });
  }

  void _updateOrderSetsCount(int newCount) {
    if (newCount < 0) return;
    setState(() {
      _orderSetsCount = newCount;
      for (var c in _editableComponents) {
        if (c['is_custom'] != true) {
          final int baseQty = (c['base_qty'] as int?) ?? 1;
          c['qty'] = newCount * baseQty;
          c['selected'] = c['qty'] > 0;
        }
      }
    });
  }

  Future<void> _showAddCustomPieceDialog() async {
    final nameCtrl = TextEditingController();
    int customQty = 1;

    await showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.add_box_rounded, color: AppTheme.primaryNavy, size: 26),
              SizedBox(width: 8),
              Text('إضافة قطعة مخصصة للطلب', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'اسم القطعة الإضافية *',
                  hintText: 'مثال: بوف كبير، خدادية كابوتنيه...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('العدد المطلوب:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Row(
                    children: [
                      Material(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            if (customQty > 1) {
                              setDialogState(() => customQty--);
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.remove, color: Colors.red, size: 20),
                          ),
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 40),
                        alignment: Alignment.center,
                        child: Text(
                          '$customQty',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryNavy),
                        ),
                      ),
                      Material(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setDialogState(() => customQty++);
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.add, color: Colors.green, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: AppTheme.royalGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final text = nameCtrl.text.trim();
                if (text.isEmpty) {
                  AppNotification.showError(context, 'يرجى كتابة اسم القطعة أولاً');
                  return;
                }
                Navigator.pop(dCtx);
                setState(() {
                  _editableComponents.add({
                    'name': text,
                    'base_qty': 0,
                    'qty': customQty,
                    'original_qty': customQty,
                    'selected': true,
                    'is_custom': true,
                  });
                });
                AppNotification.showSuccess(context, 'تمت إضافة قطعة "$text" للطلب بنجاح');
              },
              child: const Text('إضافة للطلب'),
            ),
          ],
        ),
      ),
    );
  }

  // رسالة تأكيد أنيقة لإزالة الصنف من نموذج الطلب دون المساس بالمخزن
  Future<void> _confirmRemoveCategoryFromOrder() async {
    final catName = _selectedCategory?['name'] ?? '';
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('إزالة الصنف من الطلب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في إزالة طقم "$catName" من هذا الطلب؟\n\n(ملاحظة: هذا الإجراء لا يحذف الصنف أو رصيده من المخزن نهائياً).',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('تأكيد الإزالة'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _selectedCategoryId = null;
        _editableComponents.clear();
      });
      if (mounted) {
        AppNotification.showInfo(context, 'تمت إزالة الصنف من الطلب');
      }
    }
  }

  Future<void> _submitOrder() async {
    if (_selectedCustomer == null) {
      AppNotification.showError(context, 'يرجى اختيار العميل أولاً');
      return;
    }
    if (_selectedCategory == null) {
      AppNotification.showError(context, 'يرجى اختيار الصنف أولاً');
      return;
    }
    final chosenComps = _editableComponents
        .where((c) => (c['qty'] as int) > 0)
        .map((c) => {'name': c['name'], 'qty': c['qty']})
        .toList();
    if (chosenComps.isEmpty) {
      AppNotification.showError(context, 'يرجى تحديد قطعة واحدة على الأقل وزيادة عددها عن صفر');
      return;
    }

    final db = await DBHelper.instance.database;
    await db.insert('orders', {
      'customer_id': _selectedCustomer!['id'],
      'customer_name': _selectedCustomer!['name'],
      'category_id': _selectedCategory!['id'],
      'category_name': _selectedCategory!['name'],
      'selected_components_json': jsonEncode(chosenComps),
      'specs': _specsCtrl.text.trim(),
      'delivery_date': intl.DateFormat('yyyy-MM-dd').format(_deliveryDate),
      'order_type': _orderType,
      'sets_count': _orderSetsCount > 0 ? _orderSetsCount : 1,
      'status': 'waiting',
      'created_at': intl.DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
    });

    AppEvents.instance.notifyAll();

    if (mounted) {
      AppNotification.showSuccess(
          context, 'تم تنفيذ الطلب ونقله لقائمة الانتظار بنجاح');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitleWithLogo(title: 'إدخال طلب عميل جديد'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. اختيار العميل
          DropdownButtonFormField<int>(
            value: _selectedCustomerId,
            decoration: const InputDecoration(
              labelText: 'اسم الزبون / العميل *',
              hintText: 'اختر العميل من القائمة',
              prefixIcon: Icon(Icons.person),
            ),
            items: _customers.map((c) {
              final phone =
                  (c['phone'] != null && c['phone'].toString().isNotEmpty)
                      ? ' (${c['phone']})'
                      : '';
              return DropdownMenuItem<int>(
                value: c['id'] as int,
                child: Text('${c['name']}$phone'),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedCustomerId = v),
          ),
          if (_customers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Text(
                'تنبيه: لا يوجد عملاء مسجلين! يمكنك إضافتهم من شاشة (البيانات والمخزن)',
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),

          // 2. اختيار الصنف / الطقم
          DropdownButtonFormField<int>(
            value: _selectedCategoryId,
            decoration: const InputDecoration(
              labelText: 'اسم الطقم (الصنف) *',
              hintText: 'اختر الصنف لعرض قطعه',
              prefixIcon: Icon(Icons.weekend),
            ),
            items: _categories.map((c) {
              return DropdownMenuItem<int>(
                value: c['id'] as int,
                child: Text('${c['name']} (رصيد المعرض: ${c['stock_qty']})'),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _selectedCategoryId = v;
                  final cat = _selectedCategory;
                  if (cat != null) {
                    _loadComponentsFromCategory(cat);
                  }
                });
              }
            },
          ),
          if (_categories.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Text(
                'تنبيه: لا توجد أصناف مسجلة! يمكنك إضافتها من شاشة (البيانات والمخزن)',
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),

          // 3. عرض قطع الطقم للاختيار منها وتحديد كمياتها
          if (_selectedCategory == null)
            Card(
              color: Colors.amber.shade50,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.amber.shade200)),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'يرجى اختيار اسم الطقم (الصنف) في الأعلى، وستظهر لك هنا كافة القطع المتوفرة للطقم لتحديد المطلوب منها وعددها بدقة.',
                        style: TextStyle(color: Colors.black87, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'طقم (${_selectedCategory!['name']})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryNavy),
                              ),
                              Text(
                                'رصيد المعرض الحالي: ${_selectedCategory!['stock_qty']} طقم',
                                style: const TextStyle(color: Colors.black54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
                          tooltip: 'إزالة هذا الصنف من الطلب',
                          onPressed: _confirmRemoveCategoryFromOrder,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // صندوق اختيار عدد الأطقم المطلوبة للطلب
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.royalGold.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, color: AppTheme.primaryNavy, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'عدد الأطقم المطلوبة للطلب:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Material(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    if (_orderSetsCount > 0) {
                                      _updateOrderSetsCount(_orderSetsCount - 1);
                                    }
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(6.0),
                                    child: Icon(Icons.remove, color: Colors.red, size: 20),
                                  ),
                                ),
                              ),
                              Container(
                                constraints: const BoxConstraints(minWidth: 44),
                                alignment: Alignment.center,
                                child: Text(
                                  '$_orderSetsCount',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryNavy),
                                ),
                              ),
                              Material(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    _updateOrderSetsCount(_orderSetsCount + 1);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(6.0),
                                    child: Icon(Icons.add, color: Colors.green, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),

                    // ترويسة قائمة القطع
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'قطع ومكونات الطلب (تتضاعف مع الأطقم):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              final allSelected = _editableComponents.every((c) => c['selected'] == true && c['qty'] > 0);
                              for (var c in _editableComponents) {
                                c['selected'] = !allSelected;
                                if (!allSelected) {
                                  final bq = (c['base_qty'] as int?) ?? 1;
                                  c['qty'] = bq > 0 ? bq * (_orderSetsCount > 0 ? _orderSetsCount : 1) : 1;
                                } else {
                                  c['qty'] = 0;
                                }
                              }
                            });
                          },
                          child: Text(
                            _editableComponents.every((c) => c['selected'] == true && c['qty'] > 0) ? 'إلغاء تحديد الكل' : 'تحديد الكل',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    if (_editableComponents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text('لا توجد قطع مسجلة لهذا الطقم.'),
                      )
                    else
                      ..._editableComponents.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final comp = entry.value;
                        final bool hasQty = (comp['qty'] as int) > 0;
                        final bool isSelected = comp['selected'] == true || hasQty;
                        final bool isCustom = comp['is_custom'] == true;
                        final int baseQty = (comp['base_qty'] as int?) ?? 1;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: isCustom
                                ? Colors.blue.shade50.withValues(alpha: 0.6)
                                : (isSelected
                                    ? AppTheme.royalGold.withValues(alpha: 0.12)
                                    : Colors.transparent),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCustom
                                  ? Colors.blue.shade300
                                  : (isSelected
                                      ? AppTheme.royalGold
                                      : Colors.grey.shade300),
                              width: (isSelected || isCustom) ? 1.5 : 1.0,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            activeColor: AppTheme.primaryNavy,
                            onChanged: (val) {
                              setState(() {
                                final bool check = val ?? false;
                                comp['selected'] = check;
                                if (check && comp['qty'] == 0) {
                                  comp['qty'] = isCustom ? 1 : (baseQty * (_orderSetsCount > 0 ? _orderSetsCount : 1));
                                } else if (!check) {
                                  comp['qty'] = 0;
                                }
                              });
                            },
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    comp['name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.black87 : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                if (isCustom)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'إضافية مخصصة',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              isCustom
                                  ? 'قطعة إضافية مخصصة للطلب'
                                  : 'النسبة لكل طقم: $baseQty قطعة',
                              style: const TextStyle(fontSize: 12),
                            ),
                            secondary: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCustom)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    tooltip: 'حذف هذه القطعة المخصصة',
                                    onPressed: () {
                                      setState(() {
                                        _editableComponents.removeAt(idx);
                                      });
                                    },
                                  ),
                                // زر إنقاص العدد مريح للإصبع
                                Material(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      setState(() {
                                        if (comp['qty'] > 0) {
                                          comp['qty']--;
                                          if (comp['qty'] == 0) {
                                            comp['selected'] = false;
                                          }
                                        }
                                      });
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Icon(Icons.remove, color: Colors.red, size: 20),
                                    ),
                                  ),
                                ),
                                Container(
                                  constraints: const BoxConstraints(minWidth: 36),
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    '${comp['qty']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: hasQty ? AppTheme.primaryNavy : Colors.grey,
                                    ),
                                  ),
                                ),
                                // زر زيادة العدد مريح للإصبع
                                Material(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      setState(() {
                                        comp['qty']++;
                                        comp['selected'] = true;
                                      });
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Icon(Icons.add, color: Colors.green, size: 20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 12),

                    // زر إضافة قطعة إضافية مخصصة للطلب
                    Center(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryNavy,
                          side: const BorderSide(color: AppTheme.primaryNavy),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _showAddCustomPieceDialog,
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text(
                          'إضافة قطعة إضافية مخصصة للطلب (+)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // 4. المواصفات
          TextField(
            controller: _specsCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'المواصفات وملاحظات القماش والألوان (اختياري)',
              hintText: 'مثال: قماش كتان بيج، تنجيد كابوتنيه، أرجل ستانلس...',
              prefixIcon: Icon(Icons.description),
            ),
          ),
          const SizedBox(height: 12),

          // 5. نوع الطلب (نمطي أو أوردر فقط)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.style_rounded, size: 20, color: AppTheme.primaryNavy),
                    SizedBox(width: 8),
                    Text(
                      'نوع الطلب (نمطي / أوردر):',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // نمطي
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _orderType = 'نمطي'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _orderType == 'نمطي' ? AppTheme.primaryNavy : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _orderType == 'نمطي' ? AppTheme.primaryNavy : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _orderType == 'نمطي' ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 18,
                                color: _orderType == 'نمطي' ? AppTheme.royalGold : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'نمطي',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _orderType == 'نمطي' ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // أوردر
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _orderType = 'أوردر'),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _orderType == 'أوردر' ? AppTheme.primaryNavy : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _orderType == 'أوردر' ? AppTheme.primaryNavy : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _orderType == 'أوردر' ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 18,
                                color: _orderType == 'أوردر' ? AppTheme.royalGold : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'أوردر',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _orderType == 'أوردر' ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 6. موعد التسليم
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black12),
            ),
            leading:
                const Icon(Icons.calendar_month, color: AppTheme.primaryNavy),
            title: const Text('موعد التسليم المتوقع'),
            subtitle: Text(
              intl.DateFormat('yyyy-MM-dd').format(_deliveryDate),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.primaryNavy),
            ),
            trailing: const Icon(Icons.edit_calendar),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _deliveryDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (picked != null) setState(() => _deliveryDate = picked);
            },
          ),
          const SizedBox(height: 24),

          // 7. زر تنفيذ الطلب
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: AppTheme.royalGold,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _submitOrder,
            icon: const Icon(Icons.send_and_archive_rounded),
            label: const Text(
              'تنفيذ الطلب ونقله لقائمة الانتظار',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      ),
    );
  }
}
