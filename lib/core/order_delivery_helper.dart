import 'dart:math' as math;

class OrderSetSummary {
  final int sets;
  final int individualPieces;
  final int totalPieces;

  const OrderSetSummary({
    required this.sets,
    required this.individualPieces,
    required this.totalPieces,
  });

  String? toOrangeBadgeLabel() {
    if (sets > 0 && individualPieces > 0) {
      return '$sets طقم + $individualPieces فردي';
    }
    if (sets > 0) {
      return '$sets طقم';
    }
    if (individualPieces > 0) {
      return '$individualPieces فردي';
    }
    return null;
  }
}

class DeliveryCalculationResult {
  final List<Map<String, dynamic>> deliveredComps;
  final List<Map<String, dynamic>> remainingComps;
  final List<Map<String, dynamic>> updatedCategoryComps;
  final int newCategorySets;
  final int deliveredSets;
  final int deliveredIndividualPieces;
  final int remainingOrderSets;
  final int remainingIndividualPieces;
  final int totalDeliveredPieces;
  final int totalRemainingPieces;

  bool get isFullDelivery => totalRemainingPieces == 0;

  const DeliveryCalculationResult({
    required this.deliveredComps,
    required this.remainingComps,
    required this.updatedCategoryComps,
    required this.newCategorySets,
    required this.deliveredSets,
    required this.deliveredIndividualPieces,
    required this.remainingOrderSets,
    required this.remainingIndividualPieces,
    required this.totalDeliveredPieces,
    required this.totalRemainingPieces,
  });
}

class OrderDeliveryHelper {
  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static Map<String, int> _baseQtyLookup(List<dynamic> rawCategoryComps) {
    final map = <String, int>{};
    for (final item in rawCategoryComps) {
      if (item is! Map) continue;
      final name = (item['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final base = _parseInt(item['base_qty'], fallback: 1);
      map[name] = base > 0 ? base : 1;
    }
    return map;
  }

  /// استخراج قائمة القطع القابلة للتسليم مع الحفاظ على `base_qty` لكل قطعة
  static List<Map<String, dynamic>> extractOrderPieces(
    List<dynamic> rawOrderComps,
    List<dynamic> rawCategoryComps, {
    int setsCount = 1,
  }) {
    final categoryBase = _baseQtyLookup(rawCategoryComps);

    if (rawOrderComps.isNotEmpty) {
      final result = <Map<String, dynamic>>[];
      for (final item in rawOrderComps) {
        if (item is! Map) continue;
        final name = (item['name'] ?? '').toString().trim();
        final qty = _parseInt(item['qty']);
        if (name.isEmpty || qty <= 0) continue;

        final bool isCustom = item['is_custom'] == true;
        final int rawBase = item.containsKey('base_qty')
            ? _parseInt(item['base_qty'])
            : (isCustom ? 0 : (categoryBase[name] ?? 1));
        final int safeBase = isCustom ? 0 : (rawBase > 0 ? rawBase : (categoryBase[name] ?? 1));

        result.add({
          'name': name,
          'qty': qty,
          'base_qty': safeBase,
          if (isCustom) 'is_custom': true,
        });
      }
      if (result.isNotEmpty) return result;
    }

    final safeSets = setsCount > 0 ? setsCount : 1;
    final result = <Map<String, dynamic>>[];
    for (final item in rawCategoryComps) {
      if (item is! Map) continue;
      final name = (item['name'] ?? '').toString().trim();
      final baseQty = _parseInt(item['base_qty'], fallback: 1);
      final safeBase = baseQty > 0 ? baseQty : 1;
      final qty = safeBase * safeSets;
      if (name.isNotEmpty && qty > 0) {
        result.add({
          'name': name,
          'qty': qty,
          'base_qty': safeBase,
        });
      }
    }
    return result;
  }

  /// حساب عدد الأطقم الكاملة والقطع الفردية الزائدة في قائمة قطع الطلب
  static OrderSetSummary summarizeOrder({
    required List<dynamic> orderComps,
    List<dynamic> rawCategoryComps = const [],
    int fallbackSetsCount = 0,
  }) {
    final categoryBase = _baseQtyLookup(rawCategoryComps);
    final qtyByName = <String, int>{};
    final baseByName = <String, int>{};
    final customNames = <String>{};
    int totalPieces = 0;

    for (final item in orderComps) {
      if (item is! Map) continue;
      final name = (item['name'] ?? '').toString().trim();
      final qty = math.max(0, _parseInt(item['qty']));
      if (name.isEmpty || qty <= 0) continue;

      qtyByName[name] = (qtyByName[name] ?? 0) + qty;
      totalPieces += qty;

      final bool isCustom = item['is_custom'] == true;
      if (isCustom) {
        customNames.add(name);
        baseByName[name] = 0;
      } else {
        final int rawBase = item.containsKey('base_qty')
            ? _parseInt(item['base_qty'])
            : (categoryBase[name] ?? 1);
        baseByName[name] = rawBase > 0 ? rawBase : (categoryBase[name] ?? 1);
      }
    }

    if (totalPieces == 0) {
      return OrderSetSummary(
        sets: math.max(0, fallbackSetsCount),
        individualPieces: 0,
        totalPieces: 0,
      );
    }

    int completeSets = 0;
    if (categoryBase.isNotEmpty) {
      completeSets = categoryBase.entries.map((entry) {
        final q = qtyByName[entry.key] ?? 0;
        return q ~/ entry.value;
      }).reduce(math.min);
    } else {
      final standardEntries = baseByName.entries.where((e) => e.value > 0 && !customNames.contains(e.key)).toList();
      if (standardEntries.isNotEmpty) {
        completeSets = standardEntries.map((entry) {
          final q = qtyByName[entry.key] ?? 0;
          return q ~/ entry.value;
        }).reduce(math.min);
      }
    }

    int individualPieces = 0;
    for (final entry in qtyByName.entries) {
      final name = entry.key;
      final q = entry.value;
      final int b = categoryBase[name] ?? baseByName[name] ?? 0;
      if (b > 0 && !customNames.contains(name)) {
        individualPieces += math.max(0, q - completeSets * b);
      } else {
        individualPieces += q;
      }
    }

    return OrderSetSummary(
      sets: completeSets,
      individualPieces: individualPieces,
      totalPieces: totalPieces,
    );
  }

  /// تحويل اختيار (عدد أطقم + قطع فردية إضافية) إلى كمية مسلّمة لكل قطعة
  static Map<String, int> buildDeliverQuantities({
    required List<Map<String, dynamic>> orderPieces,
    required int deliverSets,
    required Map<String, int> extraPieceQuantities,
  }) {
    final safeSets = math.max(0, deliverSets);
    final result = <String, int>{};
    for (final piece in orderPieces) {
      final name = (piece['name'] ?? '').toString().trim();
      final maxQ = math.max(0, _parseInt(piece['qty']));
      final baseQ = math.max(0, _parseInt(piece['base_qty'], fallback: piece['is_custom'] == true ? 0 : 1));
      final fromSets = safeSets * baseQ;
      final extra = math.max(0, extraPieceQuantities[name] ?? 0);
      result[name] = math.min(maxQ, fromSets + extra);
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
      final originalQty = _parseInt(piece['qty']);
      if (originalQty <= 0) continue;

      final bool isCustom = piece['is_custom'] == true;
      final int baseQty = piece.containsKey('base_qty')
          ? _parseInt(piece['base_qty'])
          : (isCustom ? 0 : 1);

      final requested = deliverQuantities[name] ?? 0;
      final toDeliver = requested.clamp(0, originalQty);
      final left = originalQty - toDeliver;

      if (toDeliver > 0) {
        deliveredComps.add({
          'name': name,
          'qty': toDeliver,
          'base_qty': baseQty,
          if (isCustom) 'is_custom': true,
        });
        deductByName[name] = (deductByName[name] ?? 0) + toDeliver;
        totalDelivered += toDeliver;
      }
      if (left > 0) {
        remainingComps.add({
          'name': name,
          'qty': left,
          'base_qty': baseQty,
          if (isCustom) 'is_custom': true,
        });
        totalRemaining += left;
      }
    }

    final updatedCategoryComps = <Map<String, dynamic>>[];
    for (final item in rawCategoryComps) {
      if (item is! Map) continue;
      final copy = Map<String, dynamic>.from(item);
      final name = (copy['name'] ?? '').toString().trim();
      final currentQty = _parseInt(copy['qty']);
      final deduct = deductByName[name] ?? 0;
      copy['qty'] = (currentQty - deduct) >= 0 ? (currentQty - deduct) : 0;
      updatedCategoryComps.add(copy);
    }

    int newCategorySets = fallbackCategoryStock;
    if (updatedCategoryComps.isNotEmpty) {
      newCategorySets = updatedCategoryComps.map<int>((c) {
        final q = _parseInt(c['qty']);
        final b = _parseInt(c['base_qty'], fallback: 1);
        return q ~/ (b > 0 ? b : 1);
      }).reduce(math.min);
    } else if (totalDelivered > 0) {
      newCategorySets = math.max(0, fallbackCategoryStock - 1);
    }

    final deliveredSummary = summarizeOrder(
      orderComps: deliveredComps,
      rawCategoryComps: rawCategoryComps,
    );
    final remainingSummary = summarizeOrder(
      orderComps: remainingComps,
      rawCategoryComps: rawCategoryComps,
    );

    return DeliveryCalculationResult(
      deliveredComps: deliveredComps,
      remainingComps: remainingComps,
      updatedCategoryComps: updatedCategoryComps,
      newCategorySets: newCategorySets,
      deliveredSets: deliveredSummary.sets,
      deliveredIndividualPieces: deliveredSummary.individualPieces,
      remainingOrderSets: remainingSummary.sets,
      remainingIndividualPieces: remainingSummary.individualPieces,
      totalDeliveredPieces: totalDelivered,
      totalRemainingPieces: totalRemaining,
    );
  }
}

