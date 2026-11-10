import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/app_events.dart';
import '../../core/app_notification.dart';
import '../../core/app_theme.dart';
import '../../core/db_helper.dart';
import '../../core/stock_movement_helper.dart';

class ShowroomStockTab extends StatefulWidget {
  const ShowroomStockTab({super.key});
  @override
  State<ShowroomStockTab> createState() => _ShowroomStockTabState();
}

class _PieceEditItem {
  final String name;
  final int baseQty;
  final TextEditingController qtyCtrl;

  _PieceEditItem({required this.name, required this.baseQty, required int qty})
      : qtyCtrl = TextEditingController(text: qty.toString());

  void dispose() {
    qtyCtrl.dispose();
  }
}

class _ShowroomStockTabState extends State<ShowroomStockTab> {
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
    AppEvents.instance.refreshNotifier.addListener(_load);
  }

  @override
  void dispose() {
    AppEvents.instance.refreshNotifier.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final db = await DBHelper.instance.database;
    final data = await db.query('categories', orderBy: 'id DESC');
    if (mounted) setState(() => _categories = data);
  }

  // نافذة تأكيد حذف صنف بالكامل
  Future<void> _confirmDeleteCategory(
    BuildContext context,
    Map<String, dynamic> cat, {
    BuildContext? modalContext,
  }) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red, size: 30),
            SizedBox(width: 8),
            Text('تأكيد حذف الصنف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف طقم "${cat['name']}" بالكامل من المخزن وقاعدة البيانات؟\nلن يمكن التراجع عن هذا الإجراء.',
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
            child: const Text('نعم، حذف الصنف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = await DBHelper.instance.database;
      await db.delete('categories', where: 'id = ?', whereArgs: [cat['id']]);
      AppEvents.instance.notifyAll();
      if (modalContext != null && modalContext.mounted) {
        Navigator.pop(modalContext);
      }
      if (mounted) {
        AppNotification.showError(context, 'تم حذف طقم "${cat['name']}" بنجاح');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // نافذة تعديل رصيد المخزن (مضاعفة أعداد القطع حسب نسبة كل قطعة بالطقم)
  // ---------------------------------------------------------------------------
  void _openEditDialog(Map<String, dynamic> cat) {
    final int currentSets = (cat['stock_qty'] as int?) ?? 0;
    final stockCtrl = TextEditingController(text: '$currentSets');

    List decoded = [];
    try {
      decoded = jsonDecode(cat['components_json']);
    } catch (_) {}

    // القطع التأسيسية المعتمدة بالمنيو ونسبتها في الطقم الواحد
    final List<_PieceEditItem> pieces = decoded.map((e) {
      final int baseQty = (e['base_qty'] is int)
          ? e['base_qty'] as int
          : ((e['qty'] is int) ? e['qty'] as int : (int.tryParse(e['qty']?.toString() ?? '1') ?? 1));
      final int initialQty = (currentSets > 0)
          ? ((e['qty'] is int) ? e['qty'] as int : (int.tryParse(e['qty']?.toString() ?? '0') ?? (currentSets * baseQty)))
          : 0;
      return _PieceEditItem(name: e['name'].toString(), baseQty: baseQty > 0 ? baseQty : 1, qty: initialQty);
    }).toList();

    if (pieces.isEmpty) {
      pieces.add(_PieceEditItem(name: 'كنبة كبيرة', baseQty: 1, qty: currentSets));
      pieces.add(_PieceEditItem(name: 'فوتيه', baseQty: 2, qty: currentSets * 2));
    }

    // دالة لمضاعفة أعداد القطع تلقائياً بضرب عدد الأطقم في عدد كل قطعة بالطقم
    void syncPiecesToSets(int sets, StateSetter setModalState) {
      setModalState(() {
        for (final p in pieces) {
          p.qtyCtrl.text = '${sets * p.baseQty}';
        }
      });
    }

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
                // رأس النافذة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.warehouse_rounded, color: AppTheme.primaryNavy, size: 26),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تعديل رصيد المخزن: ${cat['name']}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryNavy,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'عند زيادة عدد الأطقم، يتم تلقائياً مضاعفة عدد القطع حسب النسبة التأسيسية لكل قطعة بالطقم، مع إمكانية التعديل اليدوي.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 16),

                // 1. حقل إضافة طقم مع أزرار كبيرة مريحة
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
                        'إضافة طقم (عدد الأطقم بالمعرض):',
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
                                int current = int.tryParse(stockCtrl.text.trim()) ?? 0;
                                if (current > 0) {
                                  final next = current - 1;
                                  stockCtrl.text = '$next';
                                  syncPiecesToSets(next, setModalState);
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(10.0),
                                child: Icon(Icons.remove, color: Colors.red, size: 26),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // حقل إضافة طقم
                          Expanded(
                            child: TextField(
                              controller: stockCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                              decoration: const InputDecoration(
                                labelText: 'إضافة طقم',
                                prefixIcon: Icon(Icons.weekend_rounded),
                              ),
                              onChanged: (val) {
                                final n = int.tryParse(val.trim());
                                if (n != null && n >= 0) {
                                  syncPiecesToSets(n, setModalState);
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
                                int current = int.tryParse(stockCtrl.text.trim()) ?? 0;
                                final next = current + 1;
                                stockCtrl.text = '$next';
                                syncPiecesToSets(next, setModalState);
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
                const Divider(),

                // 2. سرد قطع هذا الطقم فقط وتعديل أعدادها
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'قطع الطقم بالمخزن (مضاعفة حسب الطقم مع إمكانية التعديل):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryNavy),
                    ),
                    Text(
                      '${pieces.length} قطع مسجلة',
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // عرض وتعديل أعداد قطع الطقم
                ...pieces.asMap().entries.map((entry) {
                  final piece = entry.value;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
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

                        // اسم القطعة ونسبتها التأسيسية
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                piece.name,
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
                const SizedBox(height: 20),

                // زر حفظ التعديلات في المخزن
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    foregroundColor: AppTheme.royalGold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    final validComps = <Map<String, dynamic>>[];
                    for (final p in pieces) {
                      final pName = p.name.trim();
                      if (pName.isNotEmpty) {
                        final pQty = int.tryParse(p.qtyCtrl.text.trim()) ?? 0;
                        validComps.add({
                          'name': pName,
                          'base_qty': p.baseQty,
                          'qty': pQty >= 0 ? pQty : 0,
                        });
                      }
                    }

                    final newStock = int.tryParse(stockCtrl.text.trim()) ?? 0;
                    final int oldStock = (cat['stock_qty'] as int?) ?? 0;
                    final int finalStock = newStock >= 0 ? newStock : 0;

                    final db = await DBHelper.instance.database;
                    await db.update(
                      'categories',
                      {
                        'stock_qty': finalStock,
                        'components_json': jsonEncode(validComps),
                      },
                      where: 'id = ?',
                      whereArgs: [cat['id']],
                    );

                    // 1. تسجيل حركة منفصلة لتغير رصيد المخزن الإجمالي للطقم
                    if (finalStock != oldStock) {
                      final diff = finalStock - oldStock;
                      await StockMovementHelper.logMovement(
                        categoryId: cat['id'],
                        categoryName: cat['name'],
                        movementType: diff > 0 ? 'manual_add' : 'manual_deduct',
                        qtyChange: diff,
                        stockAfter: finalStock,
                        notes: diff > 0
                            ? 'إضافة رصيد مخزن للطقم بمقدار (+$diff طقم) - أصبح $finalStock بدلاً من $oldStock'
                            : 'إنقاص رصيد مخزن للطقم ($diff طقم) - أصبح $finalStock بدلاً من $oldStock',
                      );
                    }

                    // 2. فحص وتدوين كل حركة تعديل في قطع ومكونات الطقم بحركة منفصلة لفرق العدد
                    List oldComps = [];
                    try {
                      oldComps = jsonDecode(cat['components_json']);
                    } catch (_) {}

                    for (final p in validComps) {
                      final pName = p['name'] as String;
                      final pQty = p['qty'] as int;

                      final matchingOld = oldComps.firstWhere(
                        (oc) => (oc['name'] ?? '').toString().trim() == pName.trim(),
                        orElse: () => null,
                      );

                      if (matchingOld != null) {
                        final int oldQty = (matchingOld['qty'] as int?) ?? 0;
                        final pieceDiff = pQty - oldQty;
                        if (pieceDiff != 0) {
                          await StockMovementHelper.logMovement(
                            categoryId: cat['id'],
                            categoryName: cat['name'],
                            movementType: pieceDiff > 0 ? 'piece_add' : 'piece_deduct',
                            qtyChange: pieceDiff,
                            stockAfter: finalStock,
                            notes: pieceDiff > 0
                                ? 'زيادة رصيد قطعة ($pName) بمقدار (+$pieceDiff قطعة) - أصبحت $pQty بدلاً من $oldQty'
                                : 'إنقاص رصيد قطعة ($pName) بمقدار ($pieceDiff قطعة) - أصبحت $pQty بدلاً من $oldQty',
                          );
                        }
                      }
                    }

                    AppEvents.instance.notifyAll();
                    if (mounted) {
                      Navigator.pop(ctx);
                      AppNotification.showSuccess(context, 'تم تحديث رصيد وقطع الطقم بالمخزن بنجاح');
                    }
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text(
                    'حفظ التعديلات في المخزن',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// نافذة عرض كشف حركة الطقم في المخزن
  Future<void> _openMovementsModal(Map<String, dynamic> cat) async {
    final movements = await StockMovementHelper.getMovementsForCategory(cat['id']);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 16,
          right: 16,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryNavy, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'كشف حركات طقم: ${cat['name']}',
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الرصيد الحالي بالمخزن: ${cat['stock_qty']} طقم',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy, fontSize: 14),
                  ),
                  Text(
                    'إجمالي الحركات: ${movements.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (movements.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('لا توجد حركات مسجلة لهذا الطقم حتى الآن', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: movements.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (mCtx, idx) {
                    final mov = movements[idx];
                    final type = mov['movement_type'] ?? '';
                    final int change = mov['qty_change'] ?? 0;
                    final int after = mov['stock_after'] ?? 0;
                    final notes = mov['notes'] ?? '';
                    final date = mov['created_at'] ?? '';

                    Color iconColor;
                    Color badgeBg;
                    IconData iconData;
                    String typeTitle;

                    if (type == 'delivered_out') {
                      iconColor = Colors.purple.shade700;
                      badgeBg = Colors.purple.shade50;
                      iconData = Icons.local_shipping_rounded;
                      typeTitle = 'تسليم أوردر للعميل (خصم)';
                    } else if (type == 'upholsterer_in') {
                      iconColor = Colors.green.shade800;
                      badgeBg = Colors.green.shade50;
                      iconData = Icons.assignment_turned_in_rounded;
                      typeTitle = 'استلام من المنجد (إضافة)';
                    } else if (type == 'manual_add') {
                      iconColor = Colors.teal.shade800;
                      badgeBg = Colors.teal.shade50;
                      iconData = Icons.add_circle_outline_rounded;
                      typeTitle = 'إضافة رصيد طقم بالمخزن (+)';
                    } else if (type == 'manual_deduct') {
                      iconColor = Colors.red.shade800;
                      badgeBg = Colors.red.shade50;
                      iconData = Icons.remove_circle_outline_rounded;
                      typeTitle = 'إنقاص رصيد طقم بالمخزن (-)';
                    } else if (type == 'piece_add') {
                      iconColor = Colors.indigo.shade800;
                      badgeBg = Colors.indigo.shade50;
                      iconData = Icons.playlist_add_rounded;
                      typeTitle = 'إضافة رصيد قطع للطقم (+)';
                    } else if (type == 'piece_deduct') {
                      iconColor = Colors.deepOrange.shade800;
                      badgeBg = Colors.deepOrange.shade50;
                      iconData = Icons.playlist_remove_rounded;
                      typeTitle = 'إنقاص عدد قطع الطقم (-)';
                    } else if (type == 'upholsterer_out') {
                      iconColor = Colors.orange.shade800;
                      badgeBg = Colors.orange.shade50;
                      iconData = Icons.handyman_rounded;
                      typeTitle = 'تسليم للمنجد للتشطيب';
                    } else {
                      iconColor = AppTheme.primaryNavy;
                      badgeBg = Colors.blue.shade50;
                      iconData = Icons.tune_rounded;
                      typeTitle = 'تعديل رصيد المخزن';
                    }

                    final formattedDate12 = StockMovementHelper.formatDateString12(date);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(iconData, color: iconColor, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      typeTitle,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: iconColor,
                                      ),
                                    ),
                                    if (change != 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: badgeBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          change > 0 ? '+$change' : '$change',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: iconColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  notes,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '📅 $formattedDate12',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                    Text(
                                      'رصيد الطقم: $after طقم',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // واجهة عرض المخزون مع تحسين عرض عدد الأطقم وعدد القطع بشكل لائق ومميز
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return _categories.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'لا توجد أصناف في المخزن حالياً.\nيمكنك إضافة الأصناف من تبويب (الأصناف ومكوناتها).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 80),
            itemCount: _categories.length,
            itemBuilder: (ctx, i) {
              final cat = _categories[i];
              final int qty = (cat['stock_qty'] as int?) ?? 0;
              List comps = [];
              try {
                comps = jsonDecode(cat['components_json']);
              } catch (_) {}

              return Card(
                elevation: 2.5,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: qty > 0 ? AppTheme.royalGold.withValues(alpha: 0.4) : Colors.grey.shade300,
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // الصف الأول: اسم الطقم + بادج رصيد الأطقم البارز
                      Row(
                        children: [
                          // بادج رصيد الأطقم البارز
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: qty > 0
                                    ? [AppTheme.primaryNavy, const Color(0xFF2B5282)]
                                    : [Colors.grey.shade700, Colors.grey.shade600],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'رصيد الأطقم',
                                  style: TextStyle(fontSize: 10, color: AppTheme.royalGold, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '$qty',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const Text('طقم كامل', style: TextStyle(fontSize: 10, color: Colors.white70)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // اسم الصنف وحالة التوفر
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat['name'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryNavy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: qty > 0 ? Colors.green.shade50 : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: qty > 0 ? Colors.green.shade300 : Colors.red.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        qty > 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                        size: 13,
                                        color: qty > 0 ? Colors.green.shade800 : Colors.red.shade800,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        qty > 0 ? 'جاهز بالمعرض ($qty طقم كامل)' : 'رصيد الأطقم الحالية: صفر',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: qty > 0 ? Colors.green.shade800 : Colors.red.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // زر حذف الصنف
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 22),
                            tooltip: 'حذف الصنف من المخزن',
                            onPressed: () => _confirmDeleteCategory(context, cat),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),

                      // الصف الثاني: عرض قطع الطقم بالمخزن بشكل لائق ومميز
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'قطع الطقم ورصيدها الفعلي بالمخزن:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                          ),
                          Text(
                            'إجمالي القطع: ${comps.fold<int>(0, (sum, c) => sum + ((c['qty'] as int?) ?? 0))} قطعة',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (comps.isEmpty)
                        const Text('لم يتم سرد قطع بعد لهذا الطقم', style: TextStyle(color: Colors.grey, fontSize: 12))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: comps.map((c) {
                            final String pieceName = (c['name'] ?? '').toString();
                            final int pieceCount = (c['qty'] is int)
                                ? c['qty'] as int
                                : (int.tryParse(c['qty']?.toString() ?? '0') ?? 0);

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: pieceCount > 0 ? Colors.blue.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: pieceCount > 0 ? Colors.blue.shade200 : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.chair_rounded,
                                    size: 15,
                                    color: pieceCount > 0 ? AppTheme.primaryNavy : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    pieceName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: pieceCount > 0 ? AppTheme.primaryNavy : Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: pieceCount > 0 ? AppTheme.primaryNavy : Colors.grey.shade400,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$pieceCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 14),

                      // أزرار العمليات بالأسفل
                      Row(
                        children: [
                          // زر كشف حركات الطقم في المخزن
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryNavy,
                                side: const BorderSide(color: AppTheme.primaryNavy),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _openMovementsModal(cat),
                              icon: const Icon(Icons.receipt_long_rounded, size: 18),
                              label: const Text('كشف الحركات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // زر تعديل المخزون
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryNavy,
                                foregroundColor: AppTheme.royalGold,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _openEditDialog(cat),
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('تعديل المخزون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}
