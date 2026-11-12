import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sqflite/sqflite.dart';
import '../components/app_logo.dart';
import '../components/refreshable_empty_view.dart';
import '../core/app_events.dart';
import '../core/app_notification.dart';
import '../core/app_theme.dart';
import '../core/db_helper.dart';
import '../core/stock_movement_helper.dart';
import '../core/upholsterer_statement_helper.dart';
import 'upholsterer_statement_screen.dart';

class UpholstererScreen extends StatefulWidget {
  const UpholstererScreen({super.key});
  @override
  State<UpholstererScreen> createState() => _UpholstererScreenState();
}

/// عنصر يمثل قطعة قيد التعديل في نافذة التسليم للمنجد
class _UphPieceItem {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final int baseQty;

  _UphPieceItem({required String name, required int qty, this.baseQty = 1})
      : nameCtrl = TextEditingController(text: name),
        qtyCtrl = TextEditingController(text: qty >= 0 ? qty.toString() : '0');

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
  }
}

/// عنصر يمثل قطعة قيد التعديل في نافذة تعديل دفعة المنجد
class _EditBatchPieceItem {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final int baseQty;
  final int receivedQty;
  final String sentDate;
  final String? receivedDate;

  _EditBatchPieceItem({
    required String name,
    required int sentQty,
    required this.receivedQty,
    this.baseQty = 1,
    required this.sentDate,
    this.receivedDate,
  })  : nameCtrl = TextEditingController(text: name),
        qtyCtrl = TextEditingController(text: '$sentQty');

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
  }
}

class _UpholstererScreenState extends State<UpholstererScreen> {
  List<Map<String, dynamic>> _batches = [];
  List<Map<String, dynamic>> _categories = [];

  // الدفعات الموسعة لعرض التفاصيل
  final Set<int> _expandedBatchIds = {};

  // فلاتر البحث
  final TextEditingController _searchUphCtrl = TextEditingController();
  String _searchUphName = '';
  String? _selectedCategoryFilter; // null or 'all' = الكل
  String _statusFilter = 'all'; // 'all', 'in_progress', 'completed'

  @override
  void initState() {
    super.initState();
    _load();
    AppEvents.instance.refreshNotifier.addListener(_load);
  }

  @override
  void dispose() {
    AppEvents.instance.refreshNotifier.removeListener(_load);
    _searchUphCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = await DBHelper.instance.database;
    final b = await db.query('upholsterer_batches', orderBy: 'id DESC');
    final c = await db.query('categories', orderBy: 'name ASC');
    if (mounted) {
      setState(() {
        _batches = b;
        _categories = c;
      });
    }
  }

  /// تفكيك قائمة القطع من السجل بدعم للتوافق مع البيانات القديمة
  List<Map<String, dynamic>> _parseBatchPieces(Map<String, dynamic> batch) {
    final rawJson = batch['pieces_json'];
    if (rawJson != null && rawJson.toString().trim().isNotEmpty) {
      try {
        final List list = jsonDecode(rawJson.toString());
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    // بيانات قديمة بسجل قطعة واحدة
    final int total = batch['total_sent'] is int ? batch['total_sent'] : (int.tryParse('${batch['total_sent']}') ?? 1);
    final int rec = batch['received_qty'] is int ? batch['received_qty'] : (int.tryParse('${batch['received_qty']}') ?? 0);
    return [
      {
        'name': batch['piece_name']?.toString() ?? 'قطعة',
        'sent_qty': total,
        'received_qty': rec,
        'sent_date': batch['sent_date']?.toString() ?? '',
        'received_date': batch['received_date']?.toString(),
      }
    ];
  }

  /// قائمة الدفعات بعد تطبيق الفلاتر
  List<Map<String, dynamic>> get _filteredBatches {
    return _batches.where((b) {
      final uphName = (b['upholsterer_name'] ?? '').toString().toLowerCase();
      final catName = (b['category_name'] ?? '').toString();
      final sent = (b['total_sent'] as int?) ?? 0;
      final rec = (b['received_qty'] as int?) ?? 0;
      final isDone = (sent - rec) <= 0;

      // فلتر اسم المنجد
      if (_searchUphName.trim().isNotEmpty) {
        if (!uphName.contains(_searchUphName.trim().toLowerCase())) {
          return false;
        }
      }

      // فلتر الصنف / الطقم
      if (_selectedCategoryFilter != null && _selectedCategoryFilter != 'all') {
        if (catName != _selectedCategoryFilter) {
          return false;
        }
      }

      // فلتر الحالة
      if (_statusFilter == 'in_progress' && isDone) {
        return false;
      }
      if (_statusFilter == 'completed' && !isDone) {
        return false;
      }

      return true;
    }).toList();
  }

  /// نافذة تأكيد حذف دفعة
  Future<void> _confirmDeleteBatch(Map<String, dynamic> batch) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('تأكيد حذف الدفعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف دفعة طقم "${batch['category_name']}" المسلّمة للمنجد "${batch['upholsterer_name']}"؟',
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
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = await DBHelper.instance.database;
      await db.delete('upholsterer_batches', where: 'id = ?', whereArgs: [batch['id']]);
      try {
        await db.delete('upholsterer_transactions', where: 'batch_id = ?', whereArgs: [batch['id']]);
      } catch (_) {}
      AppEvents.instance.notifyAll();
      if (mounted) {
        AppNotification.showError(context, 'تم حذف الدفعة بنجاح');
      }
    }
  }

  /// فتح شاشة كشف حساب المنجد (التسليم والاستلام مع الفلتر والمشاركة كصورة)
  void _openAccountStatement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => UpholstererStatementScreen(
          initialCategoryFilter: _selectedCategoryFilter,
        ),
      ),
    );
  }

  /// توثيق أي استلام تاريخي سابق للدفعة قبل تحديثها لأول مرة حتى لا يضيع تاريخ الاستلام القديم
  Future<void> _ensureHistoricalReceiveTrackedIfNeeded(
    Database db,
    Map<String, dynamic> originalBatch,
  ) async {
    final batchId = originalBatch['id'];
    if (batchId == null) return;
    final int recQty = (originalBatch['received_qty'] as int?) ?? 0;
    if (recQty <= 0) return;

    try {
      final existing = await db.query(
        'upholsterer_transactions',
        columns: ['id'],
        where: 'batch_id = ? AND action_type = ?',
        whereArgs: [batchId, 'receive'],
        limit: 1,
      );
      if (existing.isNotEmpty) return;

      final oldPieces = _parseBatchPieces(originalBatch);
      final Map<String, List<Map<String, dynamic>>> groupedByDate = {};
      for (final p in oldPieces) {
        final int pRec = (p['received_qty'] as int?) ?? 0;
        if (pRec <= 0) continue;
        final String dStr = (p['received_date'] ?? originalBatch['received_date'] ?? originalBatch['sent_date'] ?? '').toString().trim();
        final parsed = UpholstererStatementHelper.parseDateOnly(dStr);
        final key = parsed != null ? UpholstererStatementHelper.formatIsoDate(parsed) : dStr;
        groupedByDate.putIfAbsent(key, () => []).add({
          'name': (p['name'] ?? '').toString().trim(),
          'qty': pRec,
          'base_qty': (p['base_qty'] as int?) ?? 1,
        });
      }

      for (final entry in groupedByDate.entries) {
        int sumPieces = 0;
        for (final item in entry.value) {
          sumPieces += (item['qty'] as int?) ?? 0;
        }
        if (sumPieces <= 0) continue;
        await db.insert('upholsterer_transactions', {
          'batch_id': batchId,
          'upholsterer_name': (originalBatch['upholsterer_name'] ?? '').toString(),
          'category_id': originalBatch['category_id'],
          'category_name': originalBatch['category_name'],
          'action_type': 'receive',
          'sets_count': 0,
          'pieces_json': jsonEncode(entry.value),
          'total_pieces': sumPieces,
          'action_date': entry.key,
          'created_at': entry.key,
        });
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // 1. نافذة تسليم للمنجد (Send Modal) مطابقة لإضافة/تعديل أصناف المخزن
  // ---------------------------------------------------------------------------
  void _openSendModal() {
    if (_categories.isEmpty) {
      AppNotification.showInfo(
        context,
        'يرجى إضافة أصناف في قسم (البيانات والمخزن) أولاً لتتمكن من تسليم قطع للمنجد',
      );
      return;
    }

    final uphNameCtrl = TextEditingController();
    int selectedCatId = _categories.first['id'] as int;

    // تجميع قائمة أسماء المنجدين المسجلين سابقاً للاقتراح السريع
    final Set<String> previousUpholsterers = _batches
        .map((b) => (b['upholsterer_name'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toSet();

    // قائمة القطع القابلة للتعديل
    final List<_UphPieceItem> pieceItems = [];
    int setsToDeliver = 1;
    final setsCtrl = TextEditingController(text: '1');

    void loadCategoryPieces(int catId, int setsCount) {
      for (final p in pieceItems) {
        p.dispose();
      }
      pieceItems.clear();

      final cat = _categories.firstWhere((c) => c['id'] == catId, orElse: () => _categories.first);
      List comps = [];
      try {
        comps = jsonDecode(cat['components_json']);
      } catch (_) {}

      if (comps.isNotEmpty) {
        for (final c in comps) {
          final pName = (c['name'] ?? '').toString();
          final int baseQty = (c['base_qty'] is int)
              ? c['base_qty'] as int
              : ((c['qty'] is int) ? c['qty'] as int : (int.tryParse(c['qty']?.toString() ?? '1') ?? 1));
          final safeBase = baseQty > 0 ? baseQty : 1;
          pieceItems.add(_UphPieceItem(name: pName, qty: setsCount * safeBase, baseQty: safeBase));
        }
      } else {
        pieceItems.add(_UphPieceItem(name: 'كنبة كبيرة', qty: setsCount, baseQty: 1));
        pieceItems.add(_UphPieceItem(name: 'فوتيه', qty: setsCount * 2, baseQty: 2));
      }
    }

    // تحميل قطع الصنف الأول كافتراضي
    loadCategoryPieces(selectedCatId, setsToDeliver);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final selectedCat = _categories.firstWhere(
            (c) => c['id'] == selectedCatId,
            orElse: () => _categories.first,
          );

          void syncSets(int n) {
            setsToDeliver = n >= 0 ? n : 0;
            setsCtrl.text = '$setsToDeliver';
            for (final p in pieceItems) {
              p.qtyCtrl.text = '${setsToDeliver * p.baseQty}';
            }
          }

          return Padding(
            padding: AppTheme.modalSheetPadding(ctx),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // رأس النافذة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.send_rounded, color: AppTheme.primaryNavy, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'تسليم طقم للمنجد للتشطيب',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 1. اسم المنجد
                  TextField(
                    controller: uphNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المنجد *',
                      hintText: 'أدخل اسم المنجد أو الورشة',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),

                  // اقتراحات المنجدين السابقين
                  if (previousUpholsterers.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text('منجدون سابقون: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ...previousUpholsterers.take(5).map((name) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: ActionChip(
                                visualDensity: VisualDensity.compact,
                                label: Text(name, style: const TextStyle(fontSize: 12)),
                                onPressed: () {
                                  setModalState(() {
                                    uphNameCtrl.text = name;
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // 2. اختيار الصنف من المخزن
                  DropdownButtonFormField<int>(
                    value: selectedCatId,
                    decoration: const InputDecoration(
                      labelText: 'الصنف / الطقم المطلوب تسليمه *',
                      prefixIcon: Icon(Icons.weekend),
                    ),
                    items: _categories.map((c) {
                      return DropdownMenuItem<int>(
                        value: c['id'] as int,
                        child: Text('${c['name']} (رصيد المعرض: ${c['stock_qty']})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null && val != selectedCatId) {
                        setModalState(() {
                          selectedCatId = val;
                          loadCategoryPieces(selectedCatId, setsToDeliver);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // 3. حقل إضافة عدد الأطقم مع أزرار كبيرة ومريحة
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryNavy.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إضافة عدد الأطقم المراد تسليمها:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // زر إنقاص عدد الأطقم
                            Material(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  if (setsToDeliver > 0) {
                                    setModalState(() {
                                      syncSets(setsToDeliver - 1);
                                    });
                                  }
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(10.0),
                                  child: Icon(Icons.remove, color: Colors.red, size: 26),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // حقل عدد الأطقم
                            Expanded(
                              child: TextField(
                                controller: setsCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                decoration: const InputDecoration(
                                  labelText: 'عدد الأطقم',
                                  prefixIcon: Icon(Icons.weekend_rounded),
                                ),
                                onChanged: (val) {
                                  final n = int.tryParse(val.trim());
                                  if (n != null && n >= 0) {
                                    setModalState(() {
                                      syncSets(n);
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),

                            // زر زيادة عدد الأطقم
                            Material(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  setModalState(() {
                                    syncSets(setsToDeliver + 1);
                                  });
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(10.0),
                                  child: Icon(Icons.add, color: Colors.green, size: 26),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. قطع الطقم المسلّمة وأعدادها (سرد قطع الطقم فقط دون إضافة قطع خارجية)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'مكونات الطقم وأعداد القطع المسلّمة:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                        ),
                        Text(
                          'طقم: ${selectedCat['name']} ($setsToDeliver طقم)',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // قائمة القطع المسلّمة (مضاعفة ومسودة حسب الطقم مع إمكانية التعديل اليدوي)
                  ...pieceItems.asMap().entries.map((entry) {
                    final piece = entry.value;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chair_rounded, color: AppTheme.primaryNavy, size: 20),
                          const SizedBox(width: 8),

                          // اسم القطعة مستخرج من المنيو مع النسبة التأسيسية
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  piece.nameCtrl.text,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Text(
                                  'النسبة: عدد ${piece.baseQty} في الطقم الواحد',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // زر إنقاص عدد القطعة
                          Material(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                int q = int.tryParse(piece.qtyCtrl.text.trim()) ?? 0;
                                if (q > 0) {
                                  setModalState(() {
                                    piece.qtyCtrl.text = '${q - 1}';
                                  });
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.remove, color: Colors.red, size: 22),
                              ),
                            ),
                          ),

                          // حقل عدد القطع
                          Container(
                            width: 50,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: TextField(
                              controller: piece.qtyCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),

                          // زر زيادة عدد القطعة
                          Material(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                int q = int.tryParse(piece.qtyCtrl.text.trim()) ?? 0;
                                setModalState(() {
                                  piece.qtyCtrl.text = '${q + 1}';
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.add, color: Colors.green, size: 22),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 18),

                  // زر الحفظ
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                      foregroundColor: AppTheme.royalGold,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final uphName = uphNameCtrl.text.trim();
                      if (uphName.isEmpty) {
                        AppNotification.showError(ctx, 'يرجى إدخال اسم المنجد أولاً');
                        return;
                      }

                      final today = intl.DateFormat('yyyy-MM-dd').format(DateTime.now());

                      // تجميع القطع
                      final validPieces = <Map<String, dynamic>>[];
                      int totalSent = 0;

                      for (final p in pieceItems) {
                        final pName = p.nameCtrl.text.trim();
                        if (pName.isNotEmpty) {
                          final pQty = int.tryParse(p.qtyCtrl.text.trim()) ?? 0;
                          if (pQty > 0) {
                            totalSent += pQty;
                            validPieces.add({
                              'name': pName,
                              'base_qty': p.baseQty,
                              'sent_qty': pQty,
                              'received_qty': 0,
                              'sent_date': today,
                              'received_date': null,
                            });
                          }
                        }
                      }

                      if (validPieces.isEmpty || totalSent <= 0) {
                        AppNotification.showError(ctx, 'يرجى تحديد قطعة واحدة على الأقل للطقم');
                        return;
                      }

                      final db = await DBHelper.instance.database;
                      final int batchId = await db.insert('upholsterer_batches', {
                        'upholsterer_name': uphName,
                        'category_id': selectedCat['id'],
                        'category_name': selectedCat['name'],
                        'piece_name': validPieces.first['name'],
                        'total_sent': totalSent,
                        'received_qty': 0,
                        'sent_date': today,
                        'received_date': null,
                        'sets_sent': setsToDeliver,
                        'sets_received': 0,
                        'pieces_json': jsonEncode(validPieces),
                      });

                      try {
                        final txPieces = validPieces
                            .map((p) => {
                                  'name': p['name'],
                                  'qty': p['sent_qty'],
                                  'base_qty': p['base_qty'],
                                })
                            .toList();
                        await db.insert('upholsterer_transactions', {
                          'batch_id': batchId,
                          'upholsterer_name': uphName,
                          'category_id': selectedCat['id'],
                          'category_name': selectedCat['name'],
                          'action_type': 'send',
                          'sets_count': setsToDeliver,
                          'pieces_json': jsonEncode(txPieces),
                          'total_pieces': totalSent,
                          'action_date': UpholstererStatementHelper.formatIsoDate(DateTime.now()),
                          'created_at': StockMovementHelper.formatDateTime12(DateTime.now()),
                        });
                      } catch (_) {}

                      await StockMovementHelper.logMovement(
                        categoryId: selectedCat['id'],
                        categoryName: selectedCat['name'],
                        movementType: 'upholsterer_out',
                        qtyChange: 0,
                        stockAfter: (selectedCat['stock_qty'] as int?) ?? 0,
                        notes: 'تسليم للمنجد: $uphName (عدد $totalSent قطعة)',
                      );

                      AppEvents.instance.notifyAll();
                      if (mounted) {
                        Navigator.pop(ctx);
                        AppNotification.showSuccess(
                          context,
                          'تم تسجيل تسليم طقم (${selectedCat['name']}) للمنجد بنجاح',
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text(
                      'تسجيل التسليم للمنجد',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1.5. نافذة تعديل بيانات الدفعة والأصناف لدى المنجد
  // ---------------------------------------------------------------------------
  void _openEditBatchModal(Map<String, dynamic> initialBatch) {
    final Map<String, dynamic> batch = Map<String, dynamic>.from(initialBatch);
    final int batchId = batch['id'] as int;
    final uphNameCtrl = TextEditingController(text: (batch['upholsterer_name'] ?? '').toString());
    int setsCount = (batch['sets_sent'] as int?) ?? 1;
    final setsCtrl = TextEditingController(text: '$setsCount');

    final rawPieces = _parseBatchPieces(batch);
    final List<_EditBatchPieceItem> pieceItems = rawPieces.map((p) {
      final pName = (p['name'] ?? 'قطعة').toString();
      final int pSent = (p['sent_qty'] as int?) ?? 1;
      final int pRec = (p['received_qty'] as int?) ?? 0;
      final int bQty = (p['base_qty'] as int?) ?? 1;
      final sDate = (p['sent_date'] ?? batch['sent_date'] ?? '').toString();
      final rDate = p['received_date']?.toString();
      return _EditBatchPieceItem(
        name: pName,
        sentQty: pSent,
        receivedQty: pRec,
        baseQty: bQty > 0 ? bQty : 1,
        sentDate: sDate,
        receivedDate: rDate,
      );
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void syncEditSets(int n) {
            setsCount = n >= 0 ? n : 0;
            setsCtrl.text = '$setsCount';
            if (setsCount == 0) {
              for (final p in pieceItems) {
                // عند النزول بعدد الأطقم إلى صفر تصبح القطع صفر ما لم تكن مستلمة بالفعل
                p.qtyCtrl.text = '${p.receivedQty}';
              }
            } else {
              for (final p in pieceItems) {
                final target = setsCount * p.baseQty;
                p.qtyCtrl.text = '${target >= p.receivedQty ? target : p.receivedQty}';
              }
            }
          }

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
                      Row(
                        children: [
                          const Icon(Icons.edit_note_rounded, color: AppTheme.primaryNavy, size: 26),
                          const SizedBox(width: 8),
                          Text(
                            'تعديل الصنف: طقم (${batch['category_name']})',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // اسم المنجد
                  TextField(
                    controller: uphNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المنجد *',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // عدد الأطقم
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryNavy.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تعديل عدد الأطقم:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Material(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  if (setsCount > 0) {
                                    setModalState(() {
                                      syncEditSets(setsCount - 1);
                                    });
                                  }
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(10.0),
                                  child: Icon(Icons.remove, color: Colors.red, size: 26),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: setsCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                decoration: const InputDecoration(
                                  labelText: 'عدد الأطقم',
                                  prefixIcon: Icon(Icons.weekend_rounded),
                                ),
                                onChanged: (val) {
                                  final n = int.tryParse(val.trim());
                                  if (n != null && n >= 0) {
                                    setModalState(() {
                                      syncEditSets(n);
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Material(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  setModalState(() {
                                    syncEditSets(setsCount + 1);
                                  });
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(10.0),
                                  child: Icon(Icons.add, color: Colors.green, size: 26),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // قائمة القطع
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'قطع الطقم المسلّمة للمنجد:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                        ),
                        Text(
                          'طقم: ${batch['category_name']} ($setsCount طقم)',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  ...pieceItems.asMap().entries.map((entry) {
                    final piece = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chair_rounded, color: AppTheme.primaryNavy, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  piece.nameCtrl.text,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                if (piece.receivedQty > 0)
                                  Text(
                                    'مستلم منها: ${piece.receivedQty} قطعة (لا يمكن إنقاص المسلّم دونها)',
                                    style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                                  )
                                else
                                  Text(
                                    'النسبة: عدد ${piece.baseQty} في الطقم الواحد',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // زر إنقاص
                          Material(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                int q = int.tryParse(piece.qtyCtrl.text.trim()) ?? 0;
                                if (q > piece.receivedQty) {
                                  setModalState(() {
                                    piece.qtyCtrl.text = '${q - 1}';
                                  });
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.remove, color: Colors.red, size: 22),
                              ),
                            ),
                          ),

                          // حقل الإدخال
                          Container(
                            width: 50,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: TextField(
                              controller: piece.qtyCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),

                          // زر زيادة
                          Material(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                int q = int.tryParse(piece.qtyCtrl.text.trim()) ?? 0;
                                setModalState(() {
                                  piece.qtyCtrl.text = '${q + 1}';
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Icon(Icons.add, color: Colors.green, size: 22),
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
                      final uphName = uphNameCtrl.text.trim();
                      if (uphName.isEmpty) {
                        AppNotification.showError(ctx, 'يرجى إدخال اسم المنجد أولاً');
                        return;
                      }

                      int totalSent = 0;
                      int totalRec = 0;
                      final updatedPieces = <Map<String, dynamic>>[];

                      for (final p in pieceItems) {
                        final pName = p.nameCtrl.text.trim().isNotEmpty ? p.nameCtrl.text.trim() : 'قطعة';
                        final q = int.tryParse(p.qtyCtrl.text.trim()) ?? p.receivedQty;
                        if (q < p.receivedQty) {
                          AppNotification.showError(ctx, 'لا يمكن جعل عدد القطع المسلّمة لـ "$pName" أقل من المستلم فعلياً (${p.receivedQty})');
                          return;
                        }
                        if (q > 0 || p.receivedQty > 0) {
                          totalSent += q;
                          totalRec += p.receivedQty;
                          updatedPieces.add({
                            'name': pName,
                            'base_qty': p.baseQty,
                            'sent_qty': q,
                            'received_qty': p.receivedQty,
                            'sent_date': p.sentDate,
                            'received_date': p.receivedDate,
                          });
                        }
                      }

                      if (totalSent <= 0) {
                        AppNotification.showError(ctx, 'يرجى تحديد قطعة واحدة مسلّمة على الأقل');
                        return;
                      }

                      final db = await DBHelper.instance.database;
                      await db.update(
                        'upholsterer_batches',
                        {
                          'upholsterer_name': uphName,
                          'piece_name': updatedPieces.isNotEmpty ? updatedPieces.first['name'] : batch['piece_name'],
                          'total_sent': totalSent,
                          'received_qty': totalRec,
                          'sets_sent': setsCount,
                          'pieces_json': jsonEncode(updatedPieces),
                        },
                        where: 'id = ?',
                        whereArgs: [batchId],
                      );

                      try {
                        await db.update(
                          'upholsterer_transactions',
                          {
                            'upholsterer_name': uphName,
                          },
                          where: 'batch_id = ?',
                          whereArgs: [batchId],
                        );
                      } catch (_) {}

                      AppEvents.instance.notifyAll();
                      if (mounted) {
                        Navigator.pop(ctx);
                        AppNotification.showSuccess(context, 'تم تحديث بيانات الصنف والمنجد بنجاح');
                      }
                    },
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text(
                      'حفظ التعديلات',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. نافذة الاستلام الذكية (Receive Modal)
  // ---------------------------------------------------------------------------
  void _openReceiveModal(Map<String, dynamic> initialBatch) {
    final Map<String, dynamic> batch = Map<String, dynamic>.from(initialBatch);
    List<Map<String, dynamic>> pieces = _parseBatchPieces(batch);
    int setsToReceive = 1;

    void updateSetsToReceiveCount() {
      final currentSetsSent = (batch['sets_sent'] as int?) ?? 1;
      final currentSetsRec = (batch['sets_received'] as int?) ?? 0;
      final currentSetsRem = (currentSetsSent - currentSetsRec) > 0 ? (currentSetsSent - currentSetsRec) : 0;

      final maxSetsByPieces = pieces.isEmpty
          ? 0
          : pieces.map((p) {
              final int pSent = (p['sent_qty'] as int?) ?? 1;
              final int pRec = (p['received_qty'] as int?) ?? 0;
              final int pRem = pSent - pRec;
              final int bq = (p['base_qty'] as int?) ?? 1;
              return pRem ~/ (bq > 0 ? bq : 1);
            }).reduce(math.min);

      final maxAllowedSets = math.min(currentSetsRem, maxSetsByPieces < 0 ? 0 : maxSetsByPieces);
      if (maxAllowedSets <= 0) {
        setsToReceive = 0;
      } else if (setsToReceive > maxAllowedSets || setsToReceive <= 0) {
        setsToReceive = 1;
      }
    }

    updateSetsToReceiveCount();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          int batchSent = 0;
          int batchRec = 0;
          for (final p in pieces) {
            batchSent += (p['sent_qty'] as int?) ?? 0;
            batchRec += (p['received_qty'] as int?) ?? 0;
          }
          final int batchRemaining = batchSent - batchRec;
          final bool isBatchFullyReceived = batchRemaining <= 0;

          final int currentSetsSent = (batch['sets_sent'] as int?) ?? 1;
          final int currentSetsRec = (batch['sets_received'] as int?) ?? 0;
          final int currentSetsRem = (currentSetsSent - currentSetsRec) > 0 ? (currentSetsSent - currentSetsRec) : 0;

          final int maxSetsByPieces = pieces.isEmpty
              ? 0
              : pieces.map((p) {
                  final int pSent = (p['sent_qty'] as int?) ?? 1;
                  final int pRec = (p['received_qty'] as int?) ?? 0;
                  final int pRem = pSent - pRec;
                  final int bq = (p['base_qty'] as int?) ?? 1;
                  return pRem ~/ (bq > 0 ? bq : 1);
                }).reduce(math.min);

          final int maxAllowedSets = math.min(currentSetsRem, maxSetsByPieces < 0 ? 0 : maxSetsByPieces);
          if (setsToReceive > maxAllowedSets) {
            setsToReceive = maxAllowedSets;
          }

          return Padding(
            padding: AppTheme.modalSheetPadding(ctx),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // رأس النافذة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment_turned_in_rounded, color: Colors.green, size: 26),
                          const SizedBox(width: 8),
                          Text(
                            'استلام طقم: ${batch['category_name']}',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    'المنجد: ${batch['upholsterer_name']} | تاريخ التسليم: ${batch['sent_date']} | إجمالي الأطقم المسلّمة: $currentSetsSent طقم',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 14),

                  // 1. تحديد عدد الأطقم المستلمة (مع زر الاستلام بجانبها)
                  if (!isBatchFullyReceived && currentSetsRem > 0)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryNavy, Color(0xFF28507D)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.inventory_2_rounded, color: AppTheme.royalGold, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'تحديد عدد الأطقم المستلمة:',
                                    style: TextStyle(color: AppTheme.royalGold, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'المتبقي: $currentSetsRem طقم ($batchRemaining قطعة)',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // عداد الأطقم المستلمة
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, color: Colors.red),
                                      onPressed: setsToReceive > 0
                                          ? () => setModalState(() => setsToReceive--)
                                          : null,
                                    ),
                                    Container(
                                      constraints: const BoxConstraints(minWidth: 36),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$setsToReceive',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          color: AppTheme.primaryNavy,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, color: Colors.green),
                                      onPressed: setsToReceive < maxAllowedSets
                                          ? () => setModalState(() => setsToReceive++)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // زر استلام الأطقم المحددة بجانب العداد
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: setsToReceive > 0 ? AppTheme.royalGold : Colors.grey.shade400,
                                    foregroundColor: AppTheme.primaryNavy,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: setsToReceive > 0
                                      ? () => _confirmReceiveSets(
                                            batch: batch,
                                            pieces: pieces,
                                            setsCount: setsToReceive,
                                            modalCtx: ctx,
                                            setModalState: setModalState,
                                            onStateReset: updateSetsToReceiveCount,
                                          )
                                      : null,
                                  icon: const Icon(Icons.check_circle_rounded),
                                  label: Text(
                                    setsToReceive > 0 ? 'استلام ($setsToReceive) طقم' : 'حدد عدد الأطقم',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (maxAllowedSets < currentSetsRem) ...[
                            const SizedBox(height: 6),
                            Text(
                              'ملاحظة: تم استلام بعض القطع منفرداً، لذا أقصى عدد أطقم مكتملة القطع حالياً هو ($maxAllowedSets) طقم.',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 24),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تم اكتمال استلام كامل هذا الطقم بجميع قطعه من المنجد بنجاح!',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  const Divider(),
                  Row(
                    children: [
                      const Icon(Icons.view_list_rounded, color: AppTheme.primaryNavy, size: 20),
                      const SizedBox(width: 6),
                      const Text(
                        'إجمالي قطع الطقم (نظام تفاعلي):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy),
                      ),
                      const Spacer(),
                      if (setsToReceive > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'يتم الخصم تلقائياً لـ ($setsToReceive) طقم',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 2. قائمة القطع التفاعلية للاستلام
                  ...pieces.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final p = entry.value;
                    final pName = p['name'] ?? 'قطعة';
                    final int pSent = (p['sent_qty'] as int?) ?? 1;
                    final int pRec = (p['received_qty'] as int?) ?? 0;
                    final int pRem = pSent - pRec;
                    final int baseQty = (p['base_qty'] as int?) ?? 1;
                    final int deductedBySets = setsToReceive * (baseQty > 0 ? baseQty : 1);
                    final int interactiveRem = pRem - deductedBySets;
                    final bool isPieceDone = pRem <= 0;
                    final pSentDate = p['sent_date'] ?? batch['sent_date'];
                    final pRecDate = p['received_date'];

                    return _PieceReceiveItemWidget(
                      key: ValueKey('${batch['id']}_${pName}_${pRec}_${pRem}_${interactiveRem}_$setsToReceive'),
                      pieceName: pName,
                      baseQty: baseQty > 0 ? baseQty : 1,
                      sentQty: pSent,
                      receivedQty: pRec,
                      remainingQty: pRem,
                      deductedBySets: deductedBySets,
                      interactiveRemaining: interactiveRem >= 0 ? interactiveRem : 0,
                      sentDate: pSentDate?.toString() ?? '',
                      receivedDate: pRecDate?.toString(),
                      isDone: isPieceDone,
                      onReceivePieces: (qtyToReceive) => _confirmReceivePiece(
                        batch: batch,
                        pieces: pieces,
                        pieceIndex: idx,
                        qtyToReceive: qtyToReceive,
                        modalCtx: ctx,
                        setModalState: setModalState,
                        onStateReset: updateSetsToReceiveCount,
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// تأكيد استلام عدد محدد من الأطقم وإضافتها للمخزن مع تسجيل الحركة
  Future<void> _confirmReceiveSets({
    required Map<String, dynamic> batch,
    required List<Map<String, dynamic>> pieces,
    required int setsCount,
    required BuildContext modalCtx,
    required StateSetter setModalState,
    required VoidCallback onStateReset,
  }) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.inventory_2_rounded, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('تأكيد استلام أطقم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من استلام عدد ($setsCount) طقم من "${batch['category_name']}" من المنجد "${batch['upholsterer_name']}"؟\n\nسيتم إضافة ($setsCount) طقم وكافة قطعها التأسيسية فوراً لرصيد المخزن وتسجيل حركة بذلك.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('تأكيد الاستلام'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final today = intl.DateFormat('yyyy-MM-dd').format(DateTime.now());

    // تحديث قطع الدفعة بزيادة المستلم منها
    for (final p in pieces) {
      final baseQty = (p['base_qty'] as int?) ?? 1;
      final addQty = setsCount * (baseQty > 0 ? baseQty : 1);
      final currentRec = (p['received_qty'] as int?) ?? 0;
      p['received_qty'] = currentRec + addQty;
      p['received_date'] = today;
    }

    final int oldSetsRec = (batch['sets_received'] as int?) ?? 0;
    final int newSetsRec = oldSetsRec + setsCount;
    int newBatchRec = 0;
    int newBatchSent = 0;
    for (final p in pieces) {
      newBatchRec += (p['received_qty'] as int?) ?? 0;
      newBatchSent += (p['sent_qty'] as int?) ?? 0;
    }

    final db = await DBHelper.instance.database;
    final originalBatchSnapshot = Map<String, dynamic>.from(batch);
    // حفظ أي استلام قديم قبل تحديث التواريخ على قطع الدفعة
    final oldPieceSnapshots = await db.query('upholsterer_batches', where: 'id = ?', whereArgs: [batch['id']]);
    if (oldPieceSnapshots.isNotEmpty) {
      await _ensureHistoricalReceiveTrackedIfNeeded(db, oldPieceSnapshots.first);
    } else {
      await _ensureHistoricalReceiveTrackedIfNeeded(db, originalBatchSnapshot);
    }

    await db.update(
      'upholsterer_batches',
      {
        'sets_received': newSetsRec,
        'received_qty': newBatchRec,
        'received_date': today,
        'pieces_json': jsonEncode(pieces),
      },
      where: 'id = ?',
      whereArgs: [batch['id']],
    );

    try {
      int totalTxPieces = 0;
      final txPieces = <Map<String, dynamic>>[];
      for (final p in pieces) {
        final baseQty = (p['base_qty'] as int?) ?? 1;
        final safeBase = baseQty > 0 ? baseQty : 1;
        final addQty = setsCount * safeBase;
        totalTxPieces += addQty;
        txPieces.add({
          'name': (p['name'] ?? '').toString().trim(),
          'qty': addQty,
          'base_qty': safeBase,
        });
      }
      await db.insert('upholsterer_transactions', {
        'batch_id': batch['id'],
        'upholsterer_name': (batch['upholsterer_name'] ?? '').toString(),
        'category_id': batch['category_id'],
        'category_name': batch['category_name'],
        'action_type': 'receive',
        'sets_count': setsCount,
        'pieces_json': jsonEncode(txPieces),
        'total_pieces': totalTxPieces,
        'action_date': UpholstererStatementHelper.formatIsoDate(DateTime.now()),
        'created_at': StockMovementHelper.formatDateTime12(DateTime.now()),
      });
    } catch (_) {}

    // إضافة الأطقم وقطعها إلى جدول categories
    final catRows = await db.query('categories', where: 'id = ?', whereArgs: [batch['category_id']]);
    int newStock = setsCount;
    if (catRows.isNotEmpty) {
      final currentStock = (catRows.first['stock_qty'] as int?) ?? 0;
      newStock = currentStock + setsCount;
      List catComps = [];
      try {
        catComps = jsonDecode((catRows.first['components_json'] ?? '[]').toString());
      } catch (_) {}

      for (final p in pieces) {
        final String pName = (p['name'] ?? '').toString().trim();
        final baseQty = (p['base_qty'] as int?) ?? 1;
        final addQty = setsCount * (baseQty > 0 ? baseQty : 1);
        bool found = false;
        for (final cc in catComps) {
          if ((cc['name'] ?? '').toString().trim() == pName) {
            final oldQ = (cc['qty'] as int?) ?? 0;
            cc['qty'] = oldQ + addQty;
            found = true;
            break;
          }
        }
        if (!found) {
          catComps.add({'name': pName, 'base_qty': baseQty, 'qty': addQty});
        }
      }

      await db.update(
        'categories',
        {
          'stock_qty': newStock,
          'components_json': jsonEncode(catComps),
        },
        where: 'id = ?',
        whereArgs: [batch['category_id']],
      );
    } else {
      await db.rawUpdate('UPDATE categories SET stock_qty = stock_qty + ? WHERE id = ?', [setsCount, batch['category_id']]);
    }

    final timeStr = intl.DateFormat('hh:mm a').format(DateTime.now());
    await StockMovementHelper.logMovement(
      categoryId: batch['category_id'],
      categoryName: batch['category_name'],
      movementType: 'upholsterer_in',
      qtyChange: setsCount,
      stockAfter: newStock,
      notes: 'استلام عدد ($setsCount) طقم من المنجد: ${batch['upholsterer_name']} وإضافتها للمخزن مع قطعها (الساعة $timeStr)',
    );

    AppEvents.instance.notifyAll();

    // جلب أحدث بيانات محدثة للدفعة من قاعدة البيانات لعكسها لحظياً في النافذة
    final updatedRows = await db.query('upholsterer_batches', where: 'id = ?', whereArgs: [batch['id']]);
    if (updatedRows.isNotEmpty) {
      final fresh = updatedRows.first;
      batch.clear();
      batch.addAll(fresh);
      pieces.clear();
      pieces.addAll(_parseBatchPieces(fresh));
    } else {
      batch['sets_received'] = newSetsRec;
      batch['received_qty'] = newBatchRec;
      batch['pieces_json'] = jsonEncode(pieces);
    }

    final int totalSetsSent = (batch['sets_sent'] as int?) ?? 1;
    final int freshBatchRec = (batch['received_qty'] as int?) ?? newBatchRec;
    final int freshSetsRec = (batch['sets_received'] as int?) ?? newSetsRec;
    final bool allDone = (freshBatchRec >= newBatchSent) || (freshSetsRec >= totalSetsSent);

    if (allDone) {
      if (modalCtx.mounted) {
        Navigator.pop(modalCtx);
      }
      if (mounted) {
        AppNotification.showSuccess(
          context,
          'تم استلام كامل الأطقم والقطع من المنجد وإضافتها للمخزن بنجاح!',
        );
      }
    } else {
      onStateReset();
      setModalState(() {});
      if (mounted) {
        AppNotification.showSuccess(
          context,
          'تم استلام عدد ($setsCount) طقم وتحديث البيانات ورصيد المخزن فوراً بنجاح',
        );
      }
    }
  }

  /// تأكيد استلام عدد محدد من قطعة معينة
  Future<void> _confirmReceivePiece({
    required Map<String, dynamic> batch,
    required List<Map<String, dynamic>> pieces,
    required int pieceIndex,
    required int qtyToReceive,
    required BuildContext modalCtx,
    required StateSetter setModalState,
    required VoidCallback onStateReset,
  }) async {
    final p = pieces[pieceIndex];
    final pName = (p['name'] ?? 'القطعة').toString();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('تأكيد استلام قطعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من استلام عدد ($qtyToReceive) من قطعة "$pName" من المنجد "${batch['upholsterer_name']}"؟\n\nسيتم إضافة هذا العدد فوراً لرصيد هذه القطعة في المخزن.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('تأكيد الاستلام والإضافة للمخزن'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final today = intl.DateFormat('yyyy-MM-dd').format(DateTime.now());
    final currentRec = (p['received_qty'] as int?) ?? 0;
    p['received_qty'] = currentRec + qtyToReceive;
    p['received_date'] = today;

    int newBatchRec = 0;
    int newBatchSent = 0;
    for (final item in pieces) {
      newBatchRec += (item['received_qty'] as int?) ?? 0;
      newBatchSent += (item['sent_qty'] as int?) ?? 0;
    }

    // تحقق مما إذا اكتمل طقم كامل نتيجة استلام هذه القطعة
    int currentSetsRec = (batch['sets_received'] as int?) ?? 0;
    int calculatedSetsRec = pieces.isEmpty
        ? 0
        : pieces.map((item) {
            final ir = (item['received_qty'] as int?) ?? 0;
            final bq = (item['base_qty'] as int?) ?? 1;
            return ir ~/ (bq > 0 ? bq : 1);
          }).reduce(math.min);

    int newlyCompletedSets = 0;
    if (calculatedSetsRec > currentSetsRec) {
      newlyCompletedSets = calculatedSetsRec - currentSetsRec;
      currentSetsRec = calculatedSetsRec;
    }

    final db = await DBHelper.instance.database;
    final oldRows = await db.query('upholsterer_batches', where: 'id = ?', whereArgs: [batch['id']]);
    if (oldRows.isNotEmpty) {
      await _ensureHistoricalReceiveTrackedIfNeeded(db, oldRows.first);
    }

    await db.update(
      'upholsterer_batches',
      {
        'sets_received': currentSetsRec,
        'received_qty': newBatchRec,
        'received_date': today,
        'pieces_json': jsonEncode(pieces),
      },
      where: 'id = ?',
      whereArgs: [batch['id']],
    );

    try {
      final int pieceBase = (p['base_qty'] as int?) ?? 1;
      await db.insert('upholsterer_transactions', {
        'batch_id': batch['id'],
        'upholsterer_name': (batch['upholsterer_name'] ?? '').toString(),
        'category_id': batch['category_id'],
        'category_name': batch['category_name'],
        'action_type': 'receive',
        'sets_count': newlyCompletedSets,
        'pieces_json': jsonEncode([
          {
            'name': pName.trim(),
            'qty': qtyToReceive,
            'base_qty': pieceBase > 0 ? pieceBase : 1,
          }
        ]),
        'total_pieces': qtyToReceive,
        'action_date': UpholstererStatementHelper.formatIsoDate(DateTime.now()),
        'created_at': StockMovementHelper.formatDateTime12(DateTime.now()),
      });
    } catch (_) {}

    // إضافة رصيد هذه القطعة المستلمة فوراً إلى رصيد القطعة بجدول المخزن
    final catRows = await db.query('categories', where: 'id = ?', whereArgs: [batch['category_id']]);
    int currentCatStock = 0;
    if (catRows.isNotEmpty) {
      currentCatStock = (catRows.first['stock_qty'] as int?) ?? 0;
      List catComps = [];
      try {
        catComps = jsonDecode((catRows.first['components_json'] ?? '[]').toString());
      } catch (_) {}

      bool found = false;
      for (final cc in catComps) {
        if ((cc['name'] ?? '').toString().trim() == pName.trim()) {
          final oldQ = (cc['qty'] as int?) ?? 0;
          cc['qty'] = oldQ + qtyToReceive;
          found = true;
          break;
        }
      }
      if (!found) {
        catComps.add({'name': pName.trim(), 'qty': qtyToReceive});
      }

      int newCatStock = currentCatStock + newlyCompletedSets;

      await db.update(
        'categories',
        {
          'stock_qty': newCatStock,
          'components_json': jsonEncode(catComps),
        },
        where: 'id = ?',
        whereArgs: [batch['category_id']],
      );
      currentCatStock = newCatStock;
    }

    final timeStr = intl.DateFormat('hh:mm a').format(DateTime.now());
    await StockMovementHelper.logMovement(
      categoryId: batch['category_id'],
      categoryName: batch['category_name'],
      movementType: 'piece_add',
      qtyChange: qtyToReceive,
      stockAfter: currentCatStock,
      notes: 'استلام عدد ($qtyToReceive) من قطعة ($pName) من المنجد: ${batch['upholsterer_name']} وإضافتها للمخزن (الساعة $timeStr)',
    );

    if (newlyCompletedSets > 0) {
      await StockMovementHelper.logMovement(
        categoryId: batch['category_id'],
        categoryName: batch['category_name'],
        movementType: 'upholsterer_in',
        qtyChange: newlyCompletedSets,
        stockAfter: currentCatStock,
        notes: 'اكتمال عدد ($newlyCompletedSets) طقم بالمخزن نتيجة اكتمال استلام قطعه من المنجد (${batch['upholsterer_name']})',
      );
    }

    AppEvents.instance.notifyAll();

    // جلب أحدث بيانات محدثة للدفعة من قاعدة البيانات لعكسها لحظياً في النافذة
    final updatedRows = await db.query('upholsterer_batches', where: 'id = ?', whereArgs: [batch['id']]);
    if (updatedRows.isNotEmpty) {
      final fresh = updatedRows.first;
      batch.clear();
      batch.addAll(fresh);
      pieces.clear();
      pieces.addAll(_parseBatchPieces(fresh));
    } else {
      batch['sets_received'] = currentSetsRec;
      batch['received_qty'] = newBatchRec;
      batch['pieces_json'] = jsonEncode(pieces);
    }

    final int totalSetsSent = (batch['sets_sent'] as int?) ?? 1;
    final int freshBatchRec = (batch['received_qty'] as int?) ?? newBatchRec;
    final int freshSetsRec = (batch['sets_received'] as int?) ?? currentSetsRec;
    final bool allDone = (freshBatchRec >= newBatchSent) || (freshSetsRec >= totalSetsSent);

    if (allDone) {
      if (modalCtx.mounted) {
        Navigator.pop(modalCtx);
      }
      if (mounted) {
        AppNotification.showSuccess(
          context,
          'اكتمل استلام جميع قطع الطقم وتمت إضافتها بالكامل للمخزن بنجاح!',
        );
      }
    } else {
      onStateReset();
      setModalState(() {});
      if (mounted) {
        AppNotification.showSuccess(
          context,
          'تم استلام عدد ($qtyToReceive) من "$pName" وتحديث البيانات فوراً بنجاح',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 3. بناء واجهة الشاشة وفلاتر البحث
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final list = _filteredBatches;

    // تجميع أسماء الأصناف الفريدة للفلترة
    final Set<String> availableCategories = _batches
        .map((b) => (b['category_name'] ?? '').toString().trim())
        .where((s) => s.isNotEmpty)
        .toSet();

    final bool hasActiveFilter = _searchUphName.trim().isNotEmpty ||
        (_selectedCategoryFilter != null && _selectedCategoryFilter != 'all') ||
        _statusFilter != 'all';

    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitleWithLogo(title: 'الأصناف لدى المنجد'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: AppTheme.royalGold,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _openAccountStatement,
              icon: const Icon(Icons.receipt_long_rounded, size: 17),
              label: const Text(
                'كشف حساب',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط الفلاتر الذكي
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // فلتر اسم المنجد
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchUphCtrl,
                        decoration: InputDecoration(
                          hintText: 'بحث باسم المنجد...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          suffixIcon: _searchUphCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _searchUphCtrl.clear();
                                      _searchUphName = '';
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchUphName = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // فلتر الصنف / الطقم
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategoryFilter ?? 'all',
                        isExpanded: true,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: 'all',
                            child: Text('جميع الأطقم', overflow: TextOverflow.ellipsis),
                          ),
                          ...availableCategories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Text(cat, overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedCategoryFilter = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // فلاتر الحالة ومسح الفلتر
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _FilterChip(
                          label: 'الكل (${_batches.length})',
                          isSelected: _statusFilter == 'all',
                          onSelected: () => setState(() => _statusFilter = 'all'),
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: 'قيد العمل',
                          isSelected: _statusFilter == 'in_progress',
                          onSelected: () => setState(() => _statusFilter = 'in_progress'),
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: 'مكتملة',
                          isSelected: _statusFilter == 'completed',
                          onSelected: () => setState(() => _statusFilter = 'completed'),
                        ),
                      ],
                    ),
                    if (hasActiveFilter)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          foregroundColor: Colors.red.shade700,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchUphCtrl.clear();
                            _searchUphName = '';
                            _selectedCategoryFilter = 'all';
                            _statusFilter = 'all';
                          });
                        },
                        icon: const Icon(Icons.filter_alt_off, size: 16),
                        label: const Text('مسح الفلاتر', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // قائمة الدفعات
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: list.isEmpty
                  ? RefreshableEmptyView(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              hasActiveFilter ? Icons.search_off : Icons.handyman_outlined,
                              size: 54,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              hasActiveFilter
                                  ? 'لا توجد دفعات مطابقة لخيارات البحث المحددة.'
                                  : 'لا توجد قطع لدى المنجد حالياً.\nاضغط على (تسليم للمنجد) بالأسفل لتسجيل دفعة جديدة.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 85),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) {
                      final b = list[i];
                      final int batchId = (b['id'] as int?) ?? i;
                      final bool isExpanded = _expandedBatchIds.contains(batchId);
                      final pieces = _parseBatchPieces(b);
                      final int sent = b['total_sent'] is int ? b['total_sent'] : (int.tryParse('${b['total_sent']}') ?? 0);
                      final int rec = b['received_qty'] is int ? b['received_qty'] : (int.tryParse('${b['received_qty']}') ?? 0);
                      final int rem = sent - rec;
                      final bool isDone = rem <= 0;
                      final int bSetsSent = (b['sets_sent'] as int?) ?? 1;
                      final int bSetsRec = (b['sets_received'] as int?) ?? 0;
                      final int bSetsRem = bSetsSent - bSetsRec;

                      return Card(
                        elevation: isExpanded ? 3 : 1.5,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isDone
                                ? Colors.green.shade200
                                : (isExpanded ? AppTheme.royalGold : Colors.grey.shade300),
                            width: isExpanded ? 1.5 : 1.0,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedBatchIds.remove(batchId);
                              } else {
                                _expandedBatchIds.add(batchId);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // صف الملخص الرئيسي (دائماً ظاهر) مع زر استلام مباشر قبل التوسع والسهم الجانبي للتوسيع
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: isDone ? Colors.green.shade50 : AppTheme.primaryNavy.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.weekend_rounded,
                                        color: isDone ? Colors.green.shade700 : AppTheme.primaryNavy,
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 3,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                'طقم: ${b['category_name']}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryNavy),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDone ? Colors.green.shade50 : Colors.amber.shade50,
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: isDone ? Colors.green : Colors.amber.shade700,
                                                  ),
                                                ),
                                                child: Text(
                                                  isDone ? 'مكتمل' : 'متبقي ${bSetsRem > 0 ? '$bSetsRem طقم' : '$rem قطعة'}',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDone ? Colors.green.shade800 : Colors.amber.shade900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 2,
                                            children: [
                                              Text(
                                                'المنجد: ${b['upholsterer_name']}',
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Colors.brown),
                                              ),
                                              Text(
                                                '| الأطقم: ${(b['sets_received'] as int?) ?? 0}/${(b['sets_sent'] as int?) ?? 1} | القطع: $rec/$sent',
                                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      tooltip: 'تعديل الصنف / الدفعة',
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.primaryNavy),
                                      onPressed: () => _openEditBatchModal(b),
                                    ),
                                    const SizedBox(width: 4),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDone ? Colors.green.shade700 : AppTheme.primaryNavy,
                                        foregroundColor: isDone ? Colors.white : AppTheme.royalGold,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => _openReceiveModal(b),
                                      icon: Icon(
                                        isDone ? Icons.check_circle_outline : Icons.assignment_turned_in_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        isDone ? 'تفاصيل' : 'استلام',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      tooltip: isExpanded ? 'طي التفاصيل' : 'توسيع التفاصيل',
                                      icon: Icon(
                                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                        color: Colors.grey.shade700,
                                        size: 25,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (isExpanded) {
                                            _expandedBatchIds.remove(batchId);
                                          } else {
                                            _expandedBatchIds.add(batchId);
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),

                                // تفاصيل الطقم تظهر عند الضغط والتوسع فقط
                                if (isExpanded) ...[
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),

                                  // شريط التقدم
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: sent == 0 ? 0 : (rec / sent).clamp(0.0, 1.0),
                                      minHeight: 7,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isDone ? Colors.green : AppTheme.primaryNavy,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // تفاصيل القطع والتواريخ بتنسيق احترافي ومميز بصرياً
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.blueGrey.shade100),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Row(
                                              children: [
                                                Icon(Icons.inventory_2_outlined, size: 17, color: AppTheme.primaryNavy),
                                                SizedBox(width: 6),
                                                Text(
                                                  'تفاصيل القطع وتواريخ الإرسال والاستلام:',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isDone ? Colors.green.shade50 : Colors.amber.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isDone ? Colors.green.shade300 : Colors.amber.shade300,
                                                ),
                                              ),
                                              child: Text(
                                                isDone ? 'مكتمل الاستلام' : 'المتبقي: ${sent - rec} قطعة',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDone ? Colors.green.shade800 : Colors.amber.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        ...pieces.map((p) {
                                          final pName = (p['name'] ?? 'قطعة').toString();
                                          final int pSent = (p['sent_qty'] as int?) ?? 1;
                                          final int pRec = (p['received_qty'] as int?) ?? 0;
                                          final pSentDate = p['sent_date'] ?? b['sent_date'];
                                          final pRecDate = p['received_date'];
                                          final bool pieceDone = (pSent - pRec) <= 0;

                                          final formattedSentDate = pSentDate != null
                                              ? StockMovementHelper.formatDateString12(pSentDate.toString())
                                              : 'غير محدد';
                                          final formattedRecDate = pRecDate != null && pRecDate.toString().isNotEmpty
                                              ? StockMovementHelper.formatDateString12(pRecDate.toString())
                                              : '';

                                          final sentBlock = Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFCBD5E1)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    const Row(
                                                      children: [
                                                        Icon(Icons.outbox_rounded, size: 15, color: Color(0xFF1E3A8A)),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'المسلّم للمنجد:',
                                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A8A)),
                                                        ),
                                                      ],
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF1E3A8A),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        '$pSent قطعة',
                                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.calendar_month_rounded, size: 12, color: Colors.blueGrey),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        'تاريخ الإرسال: $formattedSentDate',
                                                        style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800, fontWeight: FontWeight.w500),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );

                                          final recBlock = Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: pRec > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: pRec > 0 ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.move_to_inbox_rounded,
                                                          size: 15,
                                                          color: pRec > 0 ? const Color(0xFF15803D) : Colors.grey.shade600,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'المستلم من المنجد:',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                            color: pRec > 0 ? const Color(0xFF15803D) : Colors.grey.shade700,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: pRec > 0 ? const Color(0xFF15803D) : Colors.grey.shade400,
                                                      ),
                                                      child: Text(
                                                        '$pRec قطعة',
                                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 5),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      pRec > 0 ? Icons.event_available_rounded : Icons.hourglass_empty_rounded,
                                                      size: 12,
                                                      color: pRec > 0 ? const Color(0xFF15803D) : Colors.grey,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        formattedRecDate.isNotEmpty
                                                            ? 'تاريخ الاستلام: $formattedRecDate'
                                                            : 'لم يتم الاستلام بعد',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: pRec > 0 ? const Color(0xFF166534) : Colors.grey.shade600,
                                                          fontWeight: pRec > 0 ? FontWeight.bold : FontWeight.normal,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: pieceDone ? Colors.green.shade200 : Colors.grey.shade200,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.02),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.chair_rounded,
                                                          size: 18,
                                                          color: pieceDone ? Colors.green : AppTheme.primaryNavy,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          pName,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 14,
                                                            color: AppTheme.primaryNavy,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: pieceDone ? Colors.green.shade50 : (pRec > 0 ? Colors.amber.shade50 : Colors.grey.shade100),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(
                                                          color: pieceDone ? Colors.green.shade300 : (pRec > 0 ? Colors.amber.shade300 : Colors.grey.shade300),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        pieceDone
                                                            ? 'مكتملة بالكامل'
                                                            : (pRec > 0 ? 'مستلم ($pRec من $pSent)' : 'قيد التنجيد (متبقي $pSent)'),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: pieceDone
                                                              ? Colors.green.shade800
                                                              : (pRec > 0 ? Colors.amber.shade900 : Colors.blueGrey.shade700),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                LayoutBuilder(
                                                  builder: (context, constraints) {
                                                    if (constraints.maxWidth < 450) {
                                                      return Column(
                                                        children: [
                                                          sentBlock,
                                                          const SizedBox(height: 6),
                                                          recBlock,
                                                        ],
                                                      );
                                                    }
                                                    return Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Expanded(child: sentBlock),
                                                        const SizedBox(width: 8),
                                                        Expanded(child: recBlock),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // أسفل البطاقة: الإجمالي وزر الاستلام وزر الحذف
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        tooltip: 'حذف هذه الدفعة',
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _confirmDeleteBatch(b),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            tooltip: 'تعديل الصنف / الدفعة',
                                            icon: const Icon(Icons.edit_outlined, size: 22, color: AppTheme.primaryNavy),
                                            onPressed: () => _openEditBatchModal(b),
                                          ),
                                          const SizedBox(width: 6),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isDone ? Colors.green.shade700 : AppTheme.primaryNavy,
                                              foregroundColor: isDone ? Colors.white : AppTheme.royalGold,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            ),
                                            onPressed: () => _openReceiveModal(b),
                                            icon: Icon(
                                              isDone ? Icons.check : Icons.assignment_turned_in_rounded,
                                              size: 18,
                                            ),
                                            label: Text(
                                              isDone ? 'تفاصيل الاستلام' : 'استلام',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: AppTheme.royalGold,
        onPressed: _openSendModal,
        icon: const Icon(Icons.send_rounded),
        label: const Text('تسليم للمنجد', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

/// زر شريحة فلترة مخصص
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryNavy : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primaryNavy : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppTheme.royalGold : Colors.black87,
          ),
        ),
      ),
    );
  }
}

/// عنصر استلام قطعة فردية داخل نافذة الاستلام بنظام تفاعلي
class _PieceReceiveItemWidget extends StatefulWidget {
  final String pieceName;
  final int baseQty;
  final int sentQty;
  final int receivedQty;
  final int remainingQty;
  final int deductedBySets;
  final int interactiveRemaining;
  final String sentDate;
  final String? receivedDate;
  final bool isDone;
  final ValueChanged<int> onReceivePieces;

  const _PieceReceiveItemWidget({
    super.key,
    required this.pieceName,
    required this.baseQty,
    required this.sentQty,
    required this.receivedQty,
    required this.remainingQty,
    required this.deductedBySets,
    required this.interactiveRemaining,
    required this.sentDate,
    required this.receivedDate,
    required this.isDone,
    required this.onReceivePieces,
  });

  @override
  State<_PieceReceiveItemWidget> createState() => _PieceReceiveItemWidgetState();
}

class _PieceReceiveItemWidgetState extends State<_PieceReceiveItemWidget> {
  int _qtyToReceive = 1;

  @override
  void initState() {
    super.initState();
    _resetQty();
  }

  @override
  void didUpdateWidget(covariant _PieceReceiveItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.interactiveRemaining != oldWidget.interactiveRemaining ||
        widget.remainingQty != oldWidget.remainingQty) {
      _resetQty();
    }
  }

  void _resetQty() {
    final maxAvail = widget.interactiveRemaining;
    if (maxAvail > 0) {
      _qtyToReceive = 1;
    } else {
      _qtyToReceive = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int maxAvail = widget.interactiveRemaining;
    final bool canReceiveSingle = maxAvail > 0 && !widget.isDone;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDone ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDone ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    widget.pieceName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.baseQty} لكل طقم',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (widget.isDone)
                const Chip(
                  backgroundColor: Colors.green,
                  label: Text('تم استلامها بالكامل', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                )
              else
                Text(
                  'المتبقي: ${widget.remainingQty} قطعة',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'المسلّم: ${widget.sentQty} (بتاريخ: ${widget.sentDate})',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                '| المستلم: ${widget.receivedQty}',
                style: const TextStyle(color: AppTheme.primaryNavy, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          if (widget.receivedDate != null && widget.receivedDate!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'آخر استلام بتاريخ: ${widget.receivedDate}',
              style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],

          // توضيح الخصم التفاعلي عند تحديد أطقم بالأعلى
          if (widget.deductedBySets > 0 && !widget.isDone) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync_alt, color: Colors.amber.shade900, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'خصم تلقائي: (${widget.deductedBySets}) قطعة مع الأطقم المحددة ➔ يتبقى بعدها: (${widget.interactiveRemaining}) قطعة',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // خيار استلام قطعة واحدة أو عدد قطع منفردة
          if (!widget.isDone) ...[
            const SizedBox(height: 10),
            if (canReceiveSingle)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('استلام منفرد: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  // زر إنقاص
                  Material(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (_qtyToReceive > 1) {
                          setState(() => _qtyToReceive--);
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.remove, size: 18),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '$_qtyToReceive',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  // زر زيادة
                  Material(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (_qtyToReceive < maxAvail) {
                          setState(() => _qtyToReceive++);
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.add, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // زر استلام القطعة
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _qtyToReceive > 0 ? () => widget.onReceivePieces(_qtyToReceive) : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text('استلام ($_qtyToReceive)'),
                  ),
                ],
              )
            else if (widget.deductedBySets > 0 && widget.interactiveRemaining == 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'سيتم استلام كامل رصيد هذه القطعة تلقائياً مع الأطقم المحددة بالأعلى.',
                  style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
