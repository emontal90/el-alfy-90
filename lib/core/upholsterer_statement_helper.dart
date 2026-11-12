import 'dart:convert';
import 'dart:math' as math;
import 'order_delivery_helper.dart';

/// نوع الحركة في كشف حساب المنجد
enum UpholstererActionType { send, receive }

/// تفاصيل عملية تسليم أو استلام واحدة ضمن الكشف
class StatementOperationItem {
  final String actionDate;
  final UpholstererActionType actionType;
  final String upholstererName;
  final int categoryId;
  final String categoryName;
  final int sets;
  final int individualPieces;
  final int totalPieces;
  final List<Map<String, dynamic>> pieces;

  const StatementOperationItem({
    required this.actionDate,
    required this.actionType,
    required this.upholstererName,
    required this.categoryId,
    required this.categoryName,
    required this.sets,
    required this.individualPieces,
    required this.totalPieces,
    required this.pieces,
  });
}

/// ملخص صنف واحد داخل قسم التسليم أو الاستلام
class StatementCategorySummary {
  final String categoryName;
  final int sets;
  final int individualPieces;
  final int totalPieces;
  final Map<String, int> pieceTotals;
  final Map<String, int> excessPieceTotals;

  const StatementCategorySummary({
    required this.categoryName,
    required this.sets,
    required this.individualPieces,
    required this.totalPieces,
    required this.pieceTotals,
    required this.excessPieceTotals,
  });
}

/// قسم كامل في كشف الحساب (إما التسليم للمنجد أو الاستلام من المنجد)
class UpholstererStatementSection {
  final int totalSets;
  final int totalIndividualPieces;
  final int totalPieces;
  final int operationsCount;
  final List<StatementCategorySummary> categorySummaries;
  final List<StatementOperationItem> operations;

  const UpholstererStatementSection({
    required this.totalSets,
    required this.totalIndividualPieces,
    required this.totalPieces,
    required this.operationsCount,
    required this.categorySummaries,
    required this.operations,
  });

  bool get isEmpty => operationsCount == 0 && totalPieces == 0;
}

/// نتيجة كشف حساب المنجد الكاملة لفترة وفلاتر محددة
class UpholstererStatementReport {
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? categoryFilter;
  final String? upholstererFilter;
  final UpholstererStatementSection deliveredToUpholsterer;
  final UpholstererStatementSection receivedFromUpholsterer;
  final int totalEventsBeforeDateFilter;

  const UpholstererStatementReport({
    required this.fromDate,
    required this.toDate,
    required this.categoryFilter,
    required this.upholstererFilter,
    required this.deliveredToUpholsterer,
    required this.receivedFromUpholsterer,
    required this.totalEventsBeforeDateFilter,
  });

  bool get hasAnyActivity =>
      !deliveredToUpholsterer.isEmpty || !receivedFromUpholsterer.isEmpty;
}

class _RawEvent {
  final UpholstererActionType actionType;
  final int? batchId;
  final String upholstererName;
  final int categoryId;
  final String categoryName;
  final DateTime? date;
  final String dateStr;
  final List<Map<String, dynamic>> pieces;

  const _RawEvent({
    required this.actionType,
    required this.batchId,
    required this.upholstererName,
    required this.categoryId,
    required this.categoryName,
    required this.date,
    required this.dateStr,
    required this.pieces,
  });
}

class UpholstererStatementHelper {
  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(normalizeDigits(value?.toString() ?? '')) ?? fallback;
  }

  /// تحويل الأرقام العربية/الهندية إلى أرقام إنجليزية قياسية لتوحيد التواريخ
  static String normalizeDigits(String input) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final arIdx = arabicDigits.indexOf(ch);
      if (arIdx != -1) {
        buffer.write(arIdx);
        continue;
      }
      final faIdx = persianDigits.indexOf(ch);
      if (faIdx != -1) {
        buffer.write(faIdx);
        continue;
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  /// تنسيق DateTime إلى yyyy-MM-dd بأرقام إنجليزية دائماً
  static String formatIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// استخراج التاريخ فقط (منتصف الليل) من نص تاريخ أو وقت
  static DateTime? parseDateOnly(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = normalizeDigits(raw.trim());
    final match = RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(normalized);
    if (match != null) {
      final y = int.tryParse(match.group(1)!);
      final m = int.tryParse(match.group(2)!);
      final d = int.tryParse(match.group(3)!);
      if (y != null && m != null && d != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return DateTime(y, m, d);
      }
    }
    final parsed = DateTime.tryParse(normalized);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    return null;
  }

  /// صياغة نص مقروء يجمع الأطقم والفردي (مثال: 2 طقم و 3 فردي)
  static String formatSetsAndIndividual(int sets, int individualPieces) {
    if (sets > 0 && individualPieces > 0) {
      return '$sets طقم و $individualPieces فردي';
    }
    if (sets > 0) {
      return '$sets طقم';
    }
    if (individualPieces > 0) {
      return '$individualPieces فردي';
    }
    return '0';
  }

  static List<Map<String, dynamic>> _parseJsonPieces(dynamic raw) {
    if (raw == null) return const [];
    try {
      final decoded = raw is List ? raw : jsonDecode(raw.toString());
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static List<Map<String, dynamic>> _parseBatchPieces(Map<String, dynamic> batch) {
    final parsed = _parseJsonPieces(batch['pieces_json']);
    if (parsed.isNotEmpty) return parsed;

    final int sent = math.max(0, _parseInt(batch['total_sent']));
    final int rec = math.max(0, _parseInt(batch['received_qty']));
    if (sent == 0 && rec == 0) return const [];
    return [
      {
        'name': (batch['piece_name'] ?? 'قطعة').toString().trim(),
        'base_qty': 1,
        'sent_qty': sent,
        'received_qty': rec,
        'sent_date': batch['sent_date'],
        'received_date': batch['received_date'],
      }
    ];
  }

  static List<dynamic> _findCategoryComponents({
    required int categoryId,
    required String categoryName,
    required Map<int, List<dynamic>> compsById,
    required Map<String, List<dynamic>> compsByName,
  }) {
    if (categoryId > 0 && compsById.containsKey(categoryId)) {
      return compsById[categoryId]!;
    }
    final normalizedName = categoryName.trim();
    if (normalizedName.isNotEmpty && compsByName.containsKey(normalizedName)) {
      return compsByName[normalizedName]!;
    }
    return const [];
  }

  /// بناء كشف حساب متكامل (التسليم مع بعضه والاستلام مع بعضه) مع دمج الحركات المسجلة والدفعات التاريخية بدون تكرار
  static UpholstererStatementReport buildStatement({
    required List<Map<String, dynamic>> batches,
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> categories,
    DateTime? fromDate,
    DateTime? toDate,
    String? categoryNameFilter,
    String? upholstererFilter,
  }) {
    final Map<int, List<dynamic>> compsById = {};
    final Map<String, List<dynamic>> compsByName = {};
    for (final cat in categories) {
      final int id = _parseInt(cat['id']);
      final String name = (cat['name'] ?? '').toString().trim();
      final List<dynamic> comps = _parseJsonPieces(cat['components_json']);
      if (id > 0) compsById[id] = comps;
      if (name.isNotEmpty) compsByName[name] = comps;
    }

    final List<_RawEvent> allEvents = [];
    final Set<int> trackedSendBatchIds = {};
    final Map<int, Map<String, int>> trackedRecByBatchAndPiece = {};

    // 1. قراءة الحركات الموثقة من جدول upholsterer_transactions
    for (final tx in transactions) {
      final String rawType = (tx['action_type'] ?? '').toString().trim();
      final UpholstererActionType actionType =
          rawType == 'send' ? UpholstererActionType.send : UpholstererActionType.receive;
      final int? batchId = tx['batch_id'] != null ? _parseInt(tx['batch_id']) : null;
      final String uphName = (tx['upholsterer_name'] ?? '').toString().trim();
      final int catId = _parseInt(tx['category_id']);
      final String catName = (tx['category_name'] ?? '').toString().trim();
      final String rawDate = (tx['action_date'] ?? tx['created_at'] ?? '').toString();
      final DateTime? parsedDate = parseDateOnly(rawDate);
      final String dateStr = parsedDate != null ? formatIsoDate(parsedDate) : normalizeDigits(rawDate);

      final rawPieces = _parseJsonPieces(tx['pieces_json']);
      final cleanPieces = <Map<String, dynamic>>[];
      for (final p in rawPieces) {
        final name = (p['name'] ?? '').toString().trim();
        final qty = math.max(0, _parseInt(p['qty']));
        final baseQty = math.max(1, _parseInt(p['base_qty'], fallback: 1));
        if (name.isEmpty || qty <= 0) continue;
        cleanPieces.add({'name': name, 'qty': qty, 'base_qty': baseQty});

        if (batchId != null && actionType == UpholstererActionType.receive) {
          final map = trackedRecByBatchAndPiece.putIfAbsent(batchId, () => {});
          map[name] = (map[name] ?? 0) + qty;
        }
      }

      if (cleanPieces.isEmpty) continue;
      if (batchId != null && actionType == UpholstererActionType.send) {
        trackedSendBatchIds.add(batchId);
      }

      allEvents.add(_RawEvent(
        actionType: actionType,
        batchId: batchId,
        upholstererName: uphName,
        categoryId: catId,
        categoryName: catName,
        date: parsedDate,
        dateStr: dateStr,
        pieces: cleanPieces,
      ));
    }

    // 2. استكمال الحركات التاريخية من جدول upholsterer_batches للدفعات المسجلة قبل تحديث التتبع
    for (final batch in batches) {
      final int? batchId = batch['id'] != null ? _parseInt(batch['id']) : null;
      final String uphName = (batch['upholsterer_name'] ?? '').toString().trim();
      final int catId = _parseInt(batch['category_id']);
      final String catName = (batch['category_name'] ?? '').toString().trim();
      final batchPieces = _parseBatchPieces(batch);

      // أ) التسليم للمنجد
      if (batchId == null || !trackedSendBatchIds.contains(batchId)) {
        final sentPieces = <Map<String, dynamic>>[];
        String? firstPieceSentDate;
        for (final p in batchPieces) {
          final name = (p['name'] ?? '').toString().trim();
          final sentQty = math.max(0, _parseInt(p['sent_qty']));
          final baseQty = math.max(1, _parseInt(p['base_qty'], fallback: 1));
          if (name.isEmpty || sentQty <= 0) continue;
          firstPieceSentDate ??= p['sent_date']?.toString();
          sentPieces.add({'name': name, 'qty': sentQty, 'base_qty': baseQty});
        }
        if (sentPieces.isNotEmpty) {
          final rawSentDate = (batch['sent_date'] ?? firstPieceSentDate ?? '').toString();
          final parsedDate = parseDateOnly(rawSentDate);
          final dateStr = parsedDate != null ? formatIsoDate(parsedDate) : normalizeDigits(rawSentDate);
          allEvents.add(_RawEvent(
            actionType: UpholstererActionType.send,
            batchId: batchId,
            upholstererName: uphName,
            categoryId: catId,
            categoryName: catName,
            date: parsedDate,
            dateStr: dateStr,
            pieces: sentPieces,
          ));
        }
      }

      // ب) الاستلام من المنجد (الفرق غير المسجل في جدول الحركات فقط)
      final Map<String, int> trackedPieceRec =
          batchId != null ? (trackedRecByBatchAndPiece[batchId] ?? const {}) : const {};
      final Map<String, List<Map<String, dynamic>>> untrackedRecByDate = {};
      final Map<String, int> seenRecQtyByName = {};

      for (final p in batchPieces) {
        final name = (p['name'] ?? '').toString().trim();
        final pRec = math.max(0, _parseInt(p['received_qty']));
        final baseQty = math.max(1, _parseInt(p['base_qty'], fallback: 1));
        if (name.isEmpty || pRec <= 0) continue;

        final alreadyCounted = seenRecQtyByName[name] ?? 0;
        final totalTrackedForName = trackedPieceRec[name] ?? 0;
        final remainingTracked = math.max(0, totalTrackedForName - alreadyCounted);
        final untrackedQty = math.max(0, pRec - remainingTracked);
        seenRecQtyByName[name] = alreadyCounted + math.min(pRec, remainingTracked);

        if (untrackedQty <= 0) continue;

        final rawRecDate = (p['received_date'] ?? batch['received_date'] ?? batch['sent_date'] ?? '').toString();
        final parsedRecDate = parseDateOnly(rawRecDate);
        final recDateKey = parsedRecDate != null
            ? formatIsoDate(parsedRecDate)
            : normalizeDigits(rawRecDate.trim());
        untrackedRecByDate.putIfAbsent(recDateKey, () => []).add({
          'name': name,
          'qty': untrackedQty,
          'base_qty': baseQty,
        });
      }

      for (final entry in untrackedRecByDate.entries) {
        final parsedDate = parseDateOnly(entry.key);
        allEvents.add(_RawEvent(
          actionType: UpholstererActionType.receive,
          batchId: batchId,
          upholstererName: uphName,
          categoryId: catId,
          categoryName: catName,
          date: parsedDate,
          dateStr: entry.key,
          pieces: entry.value,
        ));
      }
    }

    // 3. فلترة الصنف واسم المنجد (قبل فلتر التاريخ لحساب الإجمالي المتاح في القاعدة)
    final String? cleanCatFilter =
        (categoryNameFilter != null && categoryNameFilter.trim().isNotEmpty && categoryNameFilter != 'all')
            ? categoryNameFilter.trim()
            : null;
    final String? cleanUphFilter =
        (upholstererFilter != null && upholstererFilter.trim().isNotEmpty && upholstererFilter != 'all')
            ? upholstererFilter.trim()
            : null;

    final List<_RawEvent> matchingEntityEvents = allEvents.where((ev) {
      if (cleanCatFilter != null && ev.categoryName != cleanCatFilter) {
        return false;
      }
      if (cleanUphFilter != null && ev.upholstererName != cleanUphFilter) {
        return false;
      }
      return true;
    }).toList();

    // 4. تطبيق فلتر التاريخ (من - إلى) شاملة الحدين
    final DateTime? startBound =
        fromDate != null ? DateTime(fromDate.year, fromDate.month, fromDate.day) : null;
    final DateTime? endBound =
        toDate != null ? DateTime(toDate.year, toDate.month, toDate.day) : null;

    final List<_RawEvent> filteredEvents = matchingEntityEvents.where((ev) {
      if (startBound == null && endBound == null) return true;
      final d = ev.date;
      if (d == null) return false;
      if (startBound != null && d.isBefore(startBound)) return false;
      if (endBound != null && d.isAfter(endBound)) return false;
      return true;
    }).toList();

    UpholstererStatementSection buildSection(UpholstererActionType type) {
      final sectionEvents = filteredEvents.where((e) => e.actionType == type).toList()
        ..sort((a, b) {
          final da = a.date;
          final db = b.date;
          if (da != null && db != null) return db.compareTo(da);
          if (da != null) return -1;
          if (db != null) return 1;
          return b.dateStr.compareTo(a.dateStr);
        });

      final Map<String, List<_RawEvent>> eventsByCategory = {};
      for (final ev in sectionEvents) {
        final key = ev.categoryName.isNotEmpty ? ev.categoryName : 'صنف #${ev.categoryId}';
        eventsByCategory.putIfAbsent(key, () => []).add(ev);
      }

      int totalSets = 0;
      int totalIndividualPieces = 0;
      int totalPieces = 0;
      final List<StatementCategorySummary> catSummaries = [];

      final sortedCatNames = eventsByCategory.keys.toList()..sort();
      for (final catName in sortedCatNames) {
        final catEvents = eventsByCategory[catName]!;
        final int refCatId = catEvents.first.categoryId;
        final List<dynamic> rawCatComps = _findCategoryComponents(
          categoryId: refCatId,
          categoryName: catName,
          compsById: compsById,
          compsByName: compsByName,
        );

        final Map<String, int> pieceTotals = {};
        final Map<String, int> baseByName = {};
        for (final ev in catEvents) {
          for (final p in ev.pieces) {
            final pName = (p['name'] ?? '').toString().trim();
            final qty = math.max(0, _parseInt(p['qty']));
            final baseQty = math.max(1, _parseInt(p['base_qty'], fallback: 1));
            if (pName.isEmpty || qty <= 0) continue;
            pieceTotals[pName] = (pieceTotals[pName] ?? 0) + qty;
            baseByName.putIfAbsent(pName, () => baseQty);
          }
        }

        final mergedComps = pieceTotals.entries
            .map((e) => {
                  'name': e.key,
                  'qty': e.value,
                  'base_qty': baseByName[e.key] ?? 1,
                })
            .toList();

        final OrderSetSummary catSetSummary = OrderDeliveryHelper.summarizeOrder(
          orderComps: mergedComps,
          rawCategoryComps: rawCatComps,
        );

        final Map<String, int> baseLookup = {};
        for (final item in rawCatComps) {
          if (item is! Map) continue;
          final n = (item['name'] ?? '').toString().trim();
          final b = math.max(1, _parseInt(item['base_qty'], fallback: 1));
          if (n.isNotEmpty) baseLookup[n] = b;
        }

        final Map<String, int> excessPieces = {};
        for (final entry in pieceTotals.entries) {
          final int base = baseLookup[entry.key] ?? (rawCatComps.isEmpty ? (baseByName[entry.key] ?? 0) : 0);
          final int excess = base > 0
              ? math.max(0, entry.value - catSetSummary.sets * base)
              : entry.value;
          if (excess > 0) {
            excessPieces[entry.key] = excess;
          }
        }

        totalSets += catSetSummary.sets;
        totalIndividualPieces += catSetSummary.individualPieces;
        totalPieces += catSetSummary.totalPieces;

        catSummaries.add(StatementCategorySummary(
          categoryName: catName,
          sets: catSetSummary.sets,
          individualPieces: catSetSummary.individualPieces,
          totalPieces: catSetSummary.totalPieces,
          pieceTotals: pieceTotals,
          excessPieceTotals: excessPieces,
        ));
      }

      final List<StatementOperationItem> operationItems = [];
      for (final ev in sectionEvents) {
        final rawCatComps = _findCategoryComponents(
          categoryId: ev.categoryId,
          categoryName: ev.categoryName,
          compsById: compsById,
          compsByName: compsByName,
        );
        final opSummary = OrderDeliveryHelper.summarizeOrder(
          orderComps: ev.pieces,
          rawCategoryComps: rawCatComps,
        );
        operationItems.add(StatementOperationItem(
          actionDate: ev.dateStr,
          actionType: ev.actionType,
          upholstererName: ev.upholstererName,
          categoryId: ev.categoryId,
          categoryName: ev.categoryName,
          sets: opSummary.sets,
          individualPieces: opSummary.individualPieces,
          totalPieces: opSummary.totalPieces,
          pieces: ev.pieces,
        ));
      }

      return UpholstererStatementSection(
        totalSets: totalSets,
        totalIndividualPieces: totalIndividualPieces,
        totalPieces: totalPieces,
        operationsCount: operationItems.length,
        categorySummaries: catSummaries,
        operations: operationItems,
      );
    }

    return UpholstererStatementReport(
      fromDate: startBound,
      toDate: endBound,
      categoryFilter: cleanCatFilter,
      upholstererFilter: cleanUphFilter,
      deliveredToUpholsterer: buildSection(UpholstererActionType.send),
      receivedFromUpholsterer: buildSection(UpholstererActionType.receive),
      totalEventsBeforeDateFilter: matchingEntityEvents.length,
    );
  }
}

