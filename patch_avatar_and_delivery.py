import re

# 1. Update showroom_stock_tab.dart
with open(r'c:\Users\Ayman\Desktop\el-Alfy\lib\screens\management\showroom_stock_tab.dart', 'r', encoding='utf-8') as f:
    text_sh = f.read()

# Add import dart:math
if "import 'dart:math' as math;" not in text_sh:
    text_sh = "import 'dart:math' as math;\n" + text_sh

# Update save logic in _openEditStockModal
target_save = """                    final newStock = int.tryParse(stockCtrl.text.trim()) ?? 0;
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
                    );"""

replacement_save = """                    final newStock = int.tryParse(stockCtrl.text.trim()) ?? 0;
                    final int oldStock = (cat['stock_qty'] as int?) ?? 0;
                    final int finalStock = newStock >= 0 ? newStock : 0;

                    // حساب عدد الأطقم الكاملة الفعلية التي تتكون من القطع
                    final int calculatedSets = validComps.isEmpty
                        ? finalStock
                        : validComps.map<int>((p) {
                            final q = (p['qty'] as int?) ?? 0;
                            final b = (p['base_qty'] as int?) ?? 1;
                            return q ~/ (b > 0 ? b : 1);
                          }).reduce(math.min);

                    final db = await DBHelper.instance.database;
                    await db.update(
                      'categories',
                      {
                        'stock_qty': calculatedSets,
                        'components_json': jsonEncode(validComps),
                      },
                      where: 'id = ?',
                      whereArgs: [cat['id']],
                    );"""

# Update movements log if finalStock != oldStock -> calculatedSets != oldStock
target_log = """                    if (finalStock != oldStock) {
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
                    }"""

replacement_log = """                    if (calculatedSets != oldStock) {
                      final diff = calculatedSets - oldStock;
                      await StockMovementHelper.logMovement(
                        categoryId: cat['id'],
                        categoryName: cat['name'],
                        movementType: diff > 0 ? 'manual_add' : 'manual_deduct',
                        qtyChange: diff,
                        stockAfter: calculatedSets,
                        notes: diff > 0
                            ? 'إضافة رصيد مخزن للطقم بمقدار (+$diff طقم) - أصبح $calculatedSets بدلاً من $oldStock'
                            : 'تعديل رصيد مخزن للطقم ($diff طقم) - أصبح $calculatedSets بدلاً من $oldStock',
                      );
                    }"""

# Update Card build with completeSets and individualPiecesCount avatar
target_card_top = """              final int qty = (cat['stock_qty'] as int?) ?? 0;
              List comps = [];
              try {
                comps = jsonDecode(cat['components_json']);
              } catch (_) {}

              return Card("""

replacement_card_top = """              List comps = [];
              try {
                comps = jsonDecode(cat['components_json']);
              } catch (_) {}

              int completeSets = 0;
              if (comps.isNotEmpty) {
                completeSets = comps.map<int>((c) {
                  final q = (c['qty'] is int) ? c['qty'] as int : (int.tryParse(c['qty']?.toString() ?? '0') ?? 0);
                  final b = (c['base_qty'] is int) ? c['base_qty'] as int : (int.tryParse(c['base_qty']?.toString() ?? '1') ?? 1);
                  return q ~/ (b > 0 ? b : 1);
                }).reduce(math.min);
              } else {
                completeSets = (cat['stock_qty'] as int?) ?? 0;
              }

              int individualPiecesCount = 0;
              for (final c in comps) {
                final q = (c['qty'] is int) ? c['qty'] as int : (int.tryParse(c['qty']?.toString() ?? '0') ?? 0);
                final b = (c['base_qty'] is int) ? c['base_qty'] as int : (int.tryParse(c['base_qty']?.toString() ?? '1') ?? 1);
                final safeB = b > 0 ? b : 1;
                final excess = q - (completeSets * safeB);
                if (excess > 0) {
                  individualPiecesCount += excess;
                }
              }

              final int qty = completeSets;

              return Card("""

target_avatar_row = """                      // الصف الأول: اسم الطقم + بادج رصيد الأطقم البارز
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
                      ),"""

replacement_avatar_row = """                      // الصف الأول: اسم الطقم + بادج رصيد الأطقم + بادج الرصيد الفردي
                      Row(
                        children: [
                          // 1. بادج رصيد الأطقم الكاملة
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: completeSets > 0
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
                                  '$completeSets',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const Text('طقم كامل', style: TextStyle(fontSize: 9, color: Colors.white70)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 2. بادج الرصيد الفردي (القطع الزائدة عن مكونات الأطقم الفعلية)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: individualPiecesCount > 0
                                    ? [const Color(0xFFD97706), const Color(0xFFB45309)]
                                    : [Colors.blueGrey.shade800, Colors.blueGrey.shade700],
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
                                  'الرصيد الفردي',
                                  style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '$individualPiecesCount',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const Text('قطع زائدة', style: TextStyle(fontSize: 9, color: Colors.white70)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // اسم الصنف وحالة التوفر
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat['name'],
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryNavy,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: completeSets > 0 ? Colors.green.shade50 : (individualPiecesCount > 0 ? Colors.amber.shade50 : Colors.red.shade50),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: completeSets > 0 ? Colors.green.shade300 : (individualPiecesCount > 0 ? Colors.amber.shade300 : Colors.red.shade300),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        completeSets > 0 ? Icons.check_circle_rounded : (individualPiecesCount > 0 ? Icons.timelapse_rounded : Icons.info_outline_rounded),
                                        size: 13,
                                        color: completeSets > 0 ? Colors.green.shade800 : (individualPiecesCount > 0 ? Colors.amber.shade900 : Colors.red.shade800),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          completeSets > 0
                                              ? 'جاهز ($completeSets طقم ${individualPiecesCount > 0 ? "+ $individualPiecesCount فردي" : ""})'
                                              : (individualPiecesCount > 0 ? 'قطع فردية فقط ($individualPiecesCount قطعة)' : 'رصيد الأطقم: صفر'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: completeSets > 0 ? Colors.green.shade800 : (individualPiecesCount > 0 ? Colors.amber.shade900 : Colors.red.shade800),
                                          ),
                                          overflow: TextOverflow.ellipsis,
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
                      ),"""

text_sh_norm = text_sh.replace('\r\n', '\n')
target_save_norm = target_save.replace('\r\n', '\n')
replacement_save_norm = replacement_save.replace('\r\n', '\n')
target_log_norm = target_log.replace('\r\n', '\n')
replacement_log_norm = replacement_log.replace('\r\n', '\n')
target_card_top_norm = target_card_top.replace('\r\n', '\n')
replacement_card_top_norm = replacement_card_top.replace('\r\n', '\n')
target_avatar_row_norm = target_avatar_row.replace('\r\n', '\n')
replacement_avatar_row_norm = replacement_avatar_row.replace('\r\n', '\n')

text_sh_norm = text_sh_norm.replace(target_save_norm, replacement_save_norm, 1)
text_sh_norm = text_sh_norm.replace(target_log_norm, replacement_log_norm, 1)
text_sh_norm = text_sh_norm.replace(target_card_top_norm, replacement_card_top_norm, 1)
text_sh_norm = text_sh_norm.replace(target_avatar_row_norm, replacement_avatar_row_norm, 1)

with open(r'c:\Users\Ayman\Desktop\el-Alfy\lib\screens\management\showroom_stock_tab.dart', 'w', encoding='utf-8') as f:
    f.write(text_sh_norm)

print("SHOWROOM TAB UPDATED")

# 2. Update waiting_orders_screen.dart deliver logic
with open(r'c:\Users\Ayman\Desktop\el-Alfy\lib\screens\waiting_orders_screen.dart', 'r', encoding='utf-8') as f:
    text_w = f.read()

if "import 'dart:math' as math;" not in text_w:
    text_w = "import 'dart:math' as math;\n" + text_w

target_deliver = """              final db = await DBHelper.instance.database;
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
              );"""

replacement_deliver = """              final db = await DBHelper.instance.database;

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
                  validCatComps = jsonDecode(catRow['components_json'] ?? '[]');
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
              );"""

text_w_norm = text_w.replace('\r\n', '\n')
target_deliver_norm = target_deliver.replace('\r\n', '\n')
replacement_deliver_norm = replacement_deliver.replace('\r\n', '\n')

text_w_norm = text_w_norm.replace(target_deliver_norm, replacement_deliver_norm, 1)

with open(r'c:\Users\Ayman\Desktop\el-Alfy\lib\screens\waiting_orders_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text_w_norm)

print("WAITING ORDERS DELIVER LOGIC UPDATED")

