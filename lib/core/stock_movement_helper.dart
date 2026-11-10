import 'package:intl/intl.dart' as intl;
import 'db_helper.dart';

class StockMovementHelper {
  /// تحويل التاريخ والوقت إلى صيغة 12 ساعة بالعربية (ص / م)
  static String formatDateTime12(DateTime dt) {
    final dateStr = intl.DateFormat('yyyy-MM-dd').format(dt);
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'م' : 'ص';
    final hourStr = hour.toString().padLeft(2, '0');
    return '$dateStr $hourStr:$minute $period';
  }

  /// تحويل أي نص تاريخ ووقت قديم من 24 ساعة إلى 12 ساعة
  static String formatDateString12(String raw) {
    if (raw.trim().isEmpty) return '';
    if (raw.contains('ص') || raw.contains('م') || raw.contains('AM') || raw.contains('PM')) {
      return raw;
    }
    try {
      final parts = raw.trim().split(' ');
      if (parts.length >= 2) {
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');
        if (dateParts.length == 3 && timeParts.length >= 2) {
          final dt = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
          return formatDateTime12(dt);
        }
      }
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return formatDateTime12(parsed);
      }
    } catch (_) {}
    return raw;
  }

  /// تسجيل حركة مخزن جديدة وتوثيق التاريخ والوقت بصيغة 12 ساعة بدقة
  static Future<void> logMovement({
    required int categoryId,
    required String categoryName,
    required String movementType, // 'upholsterer_in', 'delivered_out', 'manual_add', 'manual_deduct', 'upholsterer_out'
    required int qtyChange,
    required int stockAfter,
    required String notes,
  }) async {
    try {
      final db = await DBHelper.instance.database;
      final nowStr = formatDateTime12(DateTime.now());
      await db.insert('stock_movements', {
        'category_id': categoryId,
        'category_name': categoryName,
        'movement_type': movementType,
        'qty_change': qtyChange,
        'stock_after': stockAfter,
        'notes': notes,
        'created_at': nowStr,
      });
    } catch (_) {}
  }

  /// جلب كشف حركة طقم معين من الأحدث للأقدم
  static Future<List<Map<String, dynamic>>> getMovementsForCategory(int categoryId) async {
    try {
      final db = await DBHelper.instance.database;
      return await db.query(
        'stock_movements',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        orderBy: 'id DESC',
      );
    } catch (_) {
      return [];
    }
  }
}
