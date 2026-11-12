import 'dart:convert';
import 'dart:math' as math;

class SecondaryCategoryStockUpdate {
  final int categoryId;
  final String categoryName;
  final int oldStockSets;
  final int newStockSets;
  final List<Map<String, dynamic>> updatedComps;
  final List<Map<String, dynamic>> deductedPieces;

  const SecondaryCategoryStockUpdate({
    required this.categoryId,
    required this.categoryName,
    required this.oldStockSets,
    required this.newStockSets,
    required this.updatedComps,
    required this.deductedPieces,
  });
}

enum OrderCompletenessStatus { complete, excess, incomplete, empty }

class OrderSetSummary {
  final int sets;
  final int individualPieces;
  final int totalPieces;

  const OrderSetSummary({
    required this.sets,
    required this.individualPieces,
    required this.totalPieces,
  });

  OrderCompletenessStatus get status {
    if (sets > 0 && individualPieces == 0) return OrderCompletenessStatus.complete;
    if (sets > 0 && individualPieces > 0) return OrderCompletenessStatus.excess;
    if (individualPieces > 0) return OrderCompletenessStatus.incomplete;
    return OrderCompletenessStatus.empty;
  }

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

  String? toStatusBadgeLabel() {
    switch (status) {
      case OrderCompletenessStatus.complete:
        return '$sets طقم (كامل)';
      case OrderCompletenessStatus.excess:
        return '$sets طقم + $individualPieces فردي (زائد)';
      case OrderCompletenessStatus.incomplete:
        return '0 طقم + $individualPieces فردي (ناقص)';
      case OrderCompletenessStatus.empty:
        return null;
    }
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

        final int? sourceCatId = item['source_category_id'] is int
            ? item['source_category_id'] as int
            : int.tryParse(item['source_category_id']?.toString() ?? '');
        final String sourceCatName = (item['source_category_name'] ?? '').toString().trim();
        final String sourcePieceName = (item['source_piece_name'] ?? '').toString().trim();

        final bool isFromOtherCategory = sourceCatId != null && sourceCatId > 0;
        final bool isCustom = item['is_custom'] == true || isFromOtherCategory;
        final int rawBase = item.containsKey('base_qty')
            ? _parseInt(item['base_qty'])
            : (isCustom ? 0 : (categoryBase[name] ?? 1));
        final int safeBase = isCustom ? 0 : (rawBase > 0 ? rawBase : (categoryBase[name] ?? 1));

        result.add({
          'name': name,
          'qty': qty,
          'base_qty': safeBase,
          if (isCustom) 'is_custom': true,
          if (isFromOtherCategory) 'source_category_id': sourceCatId,
          if (isFromOtherCategory && sourceCatName.isNotEmpty) 'source_category_name': sourceCatName,
          if (isFromOtherCategory && sourcePieceName.isNotEmpty) 'source_piece_name': sourcePieceName,
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
    int? primaryCategoryId,
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

      final int? sourceCatId = piece['source_category_id'] is int
          ? piece['source_category_id'] as int
          : int.tryParse(piece['source_category_id']?.toString() ?? '');
      final String sourceCatName = (piece['source_category_name'] ?? '').toString().trim();
      final String sourcePieceName = (piece['source_piece_name'] ?? '').toString().trim();
      final bool isFromOtherCategory = sourceCatId != null && sourceCatId > 0;
      final bool isCustom = piece['is_custom'] == true || isFromOtherCategory;
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
          if (isFromOtherCategory) 'source_category_id': sourceCatId,
          if (isFromOtherCategory && sourceCatName.isNotEmpty) 'source_category_name': sourceCatName,
          if (isFromOtherCategory && sourcePieceName.isNotEmpty) 'source_piece_name': sourcePieceName,
        });

        // يخصم من رصيد الصنف الأساسي فقط إذا كانت القطعة تابعة له (أو لم يُحدد صنف آخر مختلف)
        if (!isFromOtherCategory || (primaryCategoryId != null && sourceCatId == primaryCategoryId)) {
          final targetPieceName = (isFromOtherCategory && sourcePieceName.isNotEmpty) ? sourcePieceName : name;
          deductByName[targetPieceName] = (deductByName[targetPieceName] ?? 0) + toDeliver;
        }
        totalDelivered += toDeliver;
      }
      if (left > 0) {
        remainingComps.add({
          'name': name,
          'qty': left,
          'base_qty': baseQty,
          if (isCustom) 'is_custom': true,
          if (isFromOtherCategory) 'source_category_id': sourceCatId,
          if (isFromOtherCategory && sourceCatName.isNotEmpty) 'source_category_name': sourceCatName,
          if (isFromOtherCategory && sourcePieceName.isNotEmpty) 'source_piece_name': sourcePieceName,
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

  /// حساب خصم المخزن للأطقم الأخرى عند وجود قطع فردية مضافة من أطقم مختلفة
  static List<SecondaryCategoryStockUpdate> computeSecondaryCategoryStockUpdates({
    required List<Map<String, dynamic>> deliveredComps,
    required Map<int, Map<String, dynamic>> categoriesById,
    int? primaryCategoryId,
  }) {
    final Map<int, Map<String, int>> deductByCatId = {};

    for (final comp in deliveredComps) {
      final int? srcCatId = comp['source_category_id'] is int
          ? comp['source_category_id'] as int
          : int.tryParse(comp['source_category_id']?.toString() ?? '');
      if (srcCatId == null || srcCatId <= 0) continue;
      if (primaryCategoryId != null && srcCatId == primaryCategoryId) continue;

      final int qty = math.max(0, _parseInt(comp['qty']));
      if (qty <= 0) continue;

      final String rawPieceName = (comp['source_piece_name'] ?? comp['name'] ?? '').toString().trim();
      if (rawPieceName.isEmpty) continue;

      final catDeductMap = deductByCatId.putIfAbsent(srcCatId, () => {});
      catDeductMap[rawPieceName] = (catDeductMap[rawPieceName] ?? 0) + qty;
    }

    final updates = <SecondaryCategoryStockUpdate>[];
    for (final entry in deductByCatId.entries) {
      final catRow = categoriesById[entry.key];
      if (catRow == null) continue;

      final int oldStockSets = _parseInt(catRow['stock_qty']);
      List rawComps = [];
      try {
        final decoded = jsonDecode((catRow['components_json'] ?? '[]').toString());
        if (decoded is List) rawComps = decoded;
      } catch (_) {}

      final updatedComps = <Map<String, dynamic>>[];
      for (final item in rawComps) {
        if (item is! Map) continue;
        final copy = Map<String, dynamic>.from(item);
        final pieceName = (copy['name'] ?? '').toString().trim();
        final curQty = _parseInt(copy['qty']);
        final deduct = entry.value[pieceName] ?? 0;
        copy['qty'] = (curQty - deduct) >= 0 ? (curQty - deduct) : 0;
        updatedComps.add(copy);
      }

      int newStockSets = oldStockSets;
      if (updatedComps.isNotEmpty) {
        newStockSets = updatedComps.map<int>((c) {
          final q = _parseInt(c['qty']);
          final b = _parseInt(c['base_qty'], fallback: 1);
          return q ~/ (b > 0 ? b : 1);
        }).reduce(math.min);
      }

      final deductedPieces = entry.value.entries
          .map((e) => {'name': e.key, 'qty': e.value})
          .toList();

      updates.add(SecondaryCategoryStockUpdate(
        categoryId: entry.key,
        categoryName: (catRow['name'] ?? '').toString(),
        oldStockSets: oldStockSets,
        newStockSets: newStockSets,
        updatedComps: updatedComps,
        deductedPieces: deductedPieces,
      ));
    }

    return updates;
  }
}

