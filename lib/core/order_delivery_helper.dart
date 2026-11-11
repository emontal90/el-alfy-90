import 'dart:math' as math;

class DeliveryCalculationResult {
  final List<Map<String, dynamic>> deliveredComps;
  final List<Map<String, dynamic>> remainingComps;
  final List<Map<String, dynamic>> updatedCategoryComps;
  final int newCategorySets;
  final int remainingOrderSets;
  final int totalDeliveredPieces;
  final int totalRemainingPieces;

  bool get isFullDelivery => totalRemainingPieces == 0;

  const DeliveryCalculationResult({
    required this.deliveredComps,
    required this.remainingComps,
    required this.updatedCategoryComps,
    required this.newCategorySets,
    required this.remainingOrderSets,
    required this.totalDeliveredPieces,
    required this.totalRemainingPieces,
  });
}

class OrderDeliveryHelper {
  /// استخراج قائمة القطع القابلة للتسليم من بيانات الطلب أو مكونات الصنف الأساسية
  static List<Map<String, dynamic>> extractOrderPieces(
    List<dynamic> rawOrderComps,
    List<dynamic> rawCategoryComps, {
    int setsCount = 1,
  }) {
    if (rawOrderComps.isNotEmpty) {
      final result = <Map<String, dynamic>>[];
      for (final item in rawOrderComps) {
        if (item is! Map) continue;
        final name = (item['name'] ?? '').toString().trim();
        final qty = (item['qty'] is int)
            ? item['qty'] as int
            : (int.tryParse(item['qty']?.toString() ?? '0') ?? 0);
        if (name.isNotEmpty && qty > 0) {
          result.add({'name': name, 'qty': qty});
        }
      }
      if (result.isNotEmpty) return result;
    }

    final safeSets = setsCount > 0 ? setsCount : 1;
    final result = <Map<String, dynamic>>[];
    for (final item in rawCategoryComps) {
      if (item is! Map) continue;
      final name = (item['name'] ?? '').toString().trim();
      final baseQty = (item['base_qty'] is int)
          ? item['base_qty'] as int
          : (int.tryParse(item['base_qty']?.toString() ?? '1') ?? 1);
      final qty = (baseQty > 0 ? baseQty : 1) * safeSets;
      if (name.isNotEmpty && qty > 0) {
        result.add({'name': name, 'qty': qty});
      }
    }
    return result;
  }

  /// حساب التسليم الكلي أو الجزئي وخصم القطع المسلّمة فقط من مكونات المخزن
  static DeliveryCalculationResult computeDelivery({
    required List<Map<String, dynamic>> orderPieces,
    required Map<String, int> deliverQuantities,
    required List<dynamic> rawCategoryComps,
    int fallbackCategoryStock = 0,
  }) {
    final deliveredComps = <Map<String, dynamic>>[];
    final remainingComps = <Map<String, dynamic>>[];
    final Map<String, int> deductByName = {};

    int totalDelivered = 0;
    int totalRemaining = 0;

    for (final piece in orderPieces) {
      final name = (piece['name'] ?? '').toString().trim();
      final originalQty = (piece['qty'] is int)
          ? piece['qty'] as int
          : (int.tryParse(piece['qty']?.toString() ?? '0') ?? 0);
      if (originalQty <= 0) continue;

      final requested = deliverQuantities[name] ?? 0;
      final toDeliver = requested.clamp(0, originalQty);
      final left = originalQty - toDeliver;

      if (toDeliver > 0) {
        deliveredComps.add({'name': name, 'qty': toDeliver});
        deductByName[name] = (deductByName[name] ?? 0) + toDeliver;
        totalDelivered += toDeliver;
      }
      if (left > 0) {
        remainingComps.add({'name': name, 'qty': left});
        totalRemaining += left;
      }
    }

    final updatedCategoryComps = <Map<String, dynamic>>[];
    for (final item in rawCategoryComps) {
      if (item is! Map) continue;
      final copy = Map<String, dynamic>.from(item);
      final name = (copy['name'] ?? '').toString().trim();
      final currentQty = (copy['qty'] is int)
          ? copy['qty'] as int
          : (int.tryParse(copy['qty']?.toString() ?? '0') ?? 0);
      final deduct = deductByName[name] ?? 0;
      copy['qty'] = (currentQty - deduct) >= 0 ? (currentQty - deduct) : 0;
      updatedCategoryComps.add(copy);
    }

    int newCategorySets = fallbackCategoryStock;
    if (updatedCategoryComps.isNotEmpty) {
      newCategorySets = updatedCategoryComps.map<int>((c) {
        final q = (c['qty'] is int)
            ? c['qty'] as int
            : (int.tryParse(c['qty']?.toString() ?? '0') ?? 0);
        final b = (c['base_qty'] is int)
            ? c['base_qty'] as int
            : (int.tryParse(c['base_qty']?.toString() ?? '1') ?? 1);
        return q ~/ (b > 0 ? b : 1);
      }).reduce(math.min);
    } else if (totalDelivered > 0) {
      newCategorySets = math.max(0, fallbackCategoryStock - 1);
    }

    // تقدير عدد الأطقم الكاملة المتبقية في طلب الانتظار بعد التسليم الجزئي
    int remainingOrderSets = 0;
    if (remainingComps.isNotEmpty && updatedCategoryComps.isNotEmpty) {
      final remByName = <String, int>{
        for (final r in remainingComps) (r['name'] ?? '').toString().trim(): (r['qty'] as int? ?? 0),
      };
      if (updatedCategoryComps.every((c) => remByName.containsKey((c['name'] ?? '').toString().trim()))) {
        remainingOrderSets = updatedCategoryComps.map<int>((c) {
          final name = (c['name'] ?? '').toString().trim();
          final b = (c['base_qty'] is int)
              ? c['base_qty'] as int
              : (int.tryParse(c['base_qty']?.toString() ?? '1') ?? 1);
          return (remByName[name] ?? 0) ~/ (b > 0 ? b : 1);
        }).reduce(math.min);
      }
    }

    return DeliveryCalculationResult(
      deliveredComps: deliveredComps,
      remainingComps: remainingComps,
      updatedCategoryComps: updatedCategoryComps,
      newCategorySets: newCategorySets,
      remainingOrderSets: remainingOrderSets,
      totalDeliveredPieces: totalDelivered,
      totalRemainingPieces: totalRemaining,
    );
  }
}

