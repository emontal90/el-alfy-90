import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../components/app_logo.dart';
import '../components/stat_card.dart';
import '../core/app_events.dart';
import '../core/app_theme.dart';
import '../core/app_update_service.dart';
import '../core/app_version.dart';
import '../core/db_helper.dart';
import 'settings_hub_screen.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int tabIndex, {int? managementSubTab})? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  /// حساب إجمالي الأطقم الكاملة والقطع الفردية الزائدة وإجمالي القطع المتبقية عند المنجد
  static Map<String, int> calculateUpholstererWorkshopStats(
    List<Map<String, dynamic>> batches,
    Map<int, int> categoryComponentsCount,
  ) {
    int totalSets = 0;
    int totalIndividual = 0;
    int totalPieces = 0;

    for (final b in batches) {
      final int sent = (b['total_sent'] is int)
          ? b['total_sent'] as int
          : (int.tryParse('${b['total_sent']}') ?? 0);
      final int rec = (b['received_qty'] is int)
          ? b['received_qty'] as int
          : (int.tryParse('${b['received_qty']}') ?? 0);
      final int remBatch = sent - rec;
      if (remBatch <= 0) continue;

      List pieces = [];
      final rawPieces = b['pieces_json']?.toString() ?? '';
      if (rawPieces.trim().isNotEmpty) {
        try {
          pieces = jsonDecode(rawPieces);
        } catch (_) {}
      }

      if (pieces.isEmpty) {
        totalPieces += remBatch;
        totalIndividual += remBatch;
        continue;
      }

      final int? catId = b['category_id'] as int?;
      final int expectedComps = catId != null ? (categoryComponentsCount[catId] ?? 0) : 0;

      final List<int> remainingPerPiece = [];
      final List<int> basePerPiece = [];
      int batchPiecesSum = 0;

      for (final pItem in pieces) {
        if (pItem is! Map) continue;
        final int pSent = (pItem['sent_qty'] is int)
            ? pItem['sent_qty'] as int
            : (int.tryParse('${pItem['sent_qty']}') ?? 0);
        final int pRec = (pItem['received_qty'] is int)
            ? pItem['received_qty'] as int
            : (int.tryParse('${pItem['received_qty']}') ?? 0);
        final int pBase = (pItem['base_qty'] is int)
            ? pItem['base_qty'] as int
            : (int.tryParse('${pItem['base_qty']}') ?? 1);
        final int remQ = math.max(0, pSent - pRec);
        final int safeBase = pBase > 0 ? pBase : 1;

        remainingPerPiece.add(remQ);
        basePerPiece.add(safeBase);
        batchPiecesSum += remQ;
      }

      if (batchPiecesSum <= 0) continue;
      totalPieces += batchPiecesSum;

      if (expectedComps == 0 || remainingPerPiece.length >= expectedComps) {
        int completeSets = remainingPerPiece[0] ~/ basePerPiece[0];
        for (int i = 1; i < remainingPerPiece.length; i++) {
          completeSets = math.min(completeSets, remainingPerPiece[i] ~/ basePerPiece[i]);
        }
        int excess = 0;
        for (int i = 0; i < remainingPerPiece.length; i++) {
          excess += remainingPerPiece[i] - (completeSets * basePerPiece[i]);
        }
        totalSets += completeSets;
        totalIndividual += excess;
      } else {
        totalIndividual += batchPiecesSum;
      }
    }

    return {
      'sets': totalSets,
      'individual': totalIndividual,
      'totalPieces': totalPieces,
    };
  }

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int customersCount = 0;
  int categoriesCount = 0;
  int totalStock = 0;

  // إحصائيات قائمة الانتظار مقسومة بين نمطي وأوردر
  int waitingStandard = 0;
  int waitingCustom = 0;

  // إحصائيات تم التسليم مقسومة بين نمطي وأوردر
  int deliveredStandard = 0;
  int deliveredCustom = 0;

  int upholstererRemainingSets = 0;
  int upholstererRemainingIndividualPieces = 0;
  int upholstererRemainingPieces = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
    AppEvents.instance.refreshNotifier.addListener(_loadStats);
  }

  @override
  void dispose() {
    AppEvents.instance.refreshNotifier.removeListener(_loadStats);
    super.dispose();
  }

  Future<void> _loadStats() async {
    final db = await DBHelper.instance.database;
    final cust = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM customers')) ?? 0;
    final cats = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM categories')) ?? 0;
    final stock = Sqflite.firstIntValue(await db.rawQuery('SELECT SUM(stock_qty) FROM categories')) ?? 0;

    // أوردرات الانتظار: نمطي vs أوردر
    final waitStd = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM orders WHERE status = 'waiting' AND (order_type = 'نمطي' OR order_type = 'نمطى')"
    )) ?? 0;
    final waitCust = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM orders WHERE status = 'waiting' AND (order_type != 'نمطي' AND order_type != 'نمطى')"
    )) ?? 0;

    // الأوردرات المسلّمة: نمطي vs أوردر
    final delivStd = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM orders WHERE status = 'delivered' AND (order_type = 'نمطي' OR order_type = 'نمطى')"
    )) ?? 0;
    final delivCust = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM orders WHERE status = 'delivered' AND (order_type != 'نمطي' AND order_type != 'نمطى')"
    )) ?? 0;

    final catRows = await db.query('categories', columns: ['id', 'components_json']);
    final Map<int, int> catCompCounts = {};
    for (final c in catRows) {
      final int? id = c['id'] as int?;
      if (id == null) continue;
      try {
        final List comps = jsonDecode((c['components_json'] ?? '[]').toString());
        catCompCounts[id] = comps.length;
      } catch (_) {}
    }

    final batchRows = await db.query(
      'upholsterer_batches',
      columns: ['category_id', 'total_sent', 'received_qty', 'pieces_json'],
    );
    final uphStats = DashboardScreen.calculateUpholstererWorkshopStats(batchRows, catCompCounts);

    if (mounted) {
      setState(() {
        customersCount = cust;
        categoriesCount = cats;
        totalStock = stock;
        waitingStandard = waitStd;
        waitingCustom = waitCust;
        deliveredStandard = delivStd;
        deliveredCustom = delivCust;
        upholstererRemainingSets = uphStats['sets']!;
        upholstererRemainingIndividualPieces = uphStats['individual']!;
        upholstererRemainingPieces = uphStats['totalPieces']!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitleWithLogo(
          title: 'لوحة التحكم والتقارير',
          logoSize: 36,
        ),
        actions: [
          ValueListenableBuilder<AppUpdateInfo?>(
            valueListenable: AppUpdateService.availableUpdateNotifier,
            builder: (context, update, child) {
              return IconButton(
                tooltip: update != null ? 'تحديث جديد متاح (إصدار ${update.latestVersion})' : 'الإعدادات',
                icon: Badge(
                  isLabelVisible: update != null,
                  label: const Text(
                    '1',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: const Color(0xFFE53935),
                  alignment: AlignmentDirectional.topEnd,
                  child: const Icon(Icons.settings_rounded, color: AppTheme.primaryNavy, size: 26),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsHubScreen()),
                ).then((_) => _loadStats()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // بنر الترحيب المدمج بالشعار ورقم الإصدار
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryNavy, Color(0xFF2B5282)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const AppLogo(size: 46, showBorder: true),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  'مرحباً بك في نظام إدارة معرضك',
                                  style: TextStyle(
                                    color: AppTheme.royalGold,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.royalGold.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.royalGold.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                AppVersion.displayVersion,
                                style: const TextStyle(
                                  color: AppTheme.royalGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'نظام الألفي لإدارة الأثاث والمخازن والطلبيات',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // شبكة الكروت الإحصائية
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: MediaQuery.sizeOf(context).width < 380 ? 1.05 : 1.15,
              children: [
                // 1. كارت قائمة الانتظار مقسوم إلى نصفين: نمطي وأوردر
                SplitStatCard(
                  title: 'قائمة الانتظار',
                  icon: Icons.pending_actions_rounded,
                  color: Colors.orange.shade800,
                  standardCount: waitingStandard,
                  customCount: waitingCustom,
                  onTap: () => widget.onNavigateTab?.call(1),
                ),

                // 2. كارت تم التسليم مقسوم إلى نصفين: نمطي وأوردر
                SplitStatCard(
                  title: 'تم التسليم',
                  icon: Icons.task_alt_rounded,
                  color: Colors.green.shade700,
                  standardCount: deliveredStandard,
                  customCount: deliveredCustom,
                  onTap: () => widget.onNavigateTab?.call(2),
                ),

                // 3. مخزن المعرض
                StatCard(
                  title: 'مخزن المعرض',
                  value: '$totalStock طقم جاهز',
                  icon: Icons.storefront_rounded,
                  color: AppTheme.primaryNavy,
                  onTap: () => widget.onNavigateTab?.call(4, managementSubTab: 0),
                ),

                // 4. ورشة المنجد (أطقم كاملة وفردي في نفس الكارت)
                SplitStatCard(
                  title: 'ورشة المنجد',
                  icon: Icons.chair_alt_rounded,
                  color: Colors.purple.shade700,
                  standardCount: upholstererRemainingSets,
                  customCount: upholstererRemainingIndividualPieces,
                  firstLabel: 'أطقم',
                  secondLabel: 'فردي',
                  footerText: 'إجمالي القطع: $upholstererRemainingPieces',
                  onTap: () => widget.onNavigateTab?.call(3),
                ),

                // 5. سجل العملاء
                StatCard(
                  title: 'سجل العملاء',
                  value: '$customersCount عميل',
                  icon: Icons.people_alt_rounded,
                  color: Colors.teal.shade700,
                  onTap: () => widget.onNavigateTab?.call(4, managementSubTab: 2),
                ),

                // 6. قائمة الأصناف
                StatCard(
                  title: 'قائمة الأصناف',
                  value: '$categoriesCount صنف',
                  icon: Icons.category_rounded,
                  color: Colors.brown.shade700,
                  onTap: () => widget.onNavigateTab?.call(4, managementSubTab: 1),
                ),
              ],
            ),
            const SizedBox(height: 76),
          ],
        ),
      ),
    );
  }
}
