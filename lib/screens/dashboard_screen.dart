import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../components/app_logo.dart';
import '../components/distinctive_refresh_button.dart';
import '../components/stat_card.dart';
import '../core/app_events.dart';
import '../core/app_theme.dart';
import '../core/backup_service.dart';
import '../core/db_helper.dart';
import 'backup_screen.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int tabIndex, {int? managementSubTab})? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});
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

    final uph = Sqflite.firstIntValue(await db.rawQuery('SELECT SUM(total_sent - received_qty) FROM upholsterer_batches')) ?? 0;

    if (mounted) {
      setState(() {
        customersCount = cust;
        categoriesCount = cats;
        totalStock = stock;
        waitingStandard = waitStd;
        waitingCustom = waitCust;
        deliveredStandard = delivStd;
        deliveredCustom = delivCust;
        upholstererRemainingPieces = uph;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            AppLogo(size: 38),
            SizedBox(width: 12),
            Text('لوحة التحكم والتقارير', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          const DistinctiveRefreshButton(),
          IconButton(
            tooltip: 'تنظيف الكاش وتسريع البرنامج',
            icon: const Icon(Icons.cleaning_services_rounded),
            onPressed: () async {
              final msg = await BackupService.clearAppCache();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              }
            },
          ),
          IconButton(
            tooltip: 'النسخ الاحتياطي',
            icon: const Icon(Icons.backup_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())).then((_) => _loadStats()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // بنر الترحيب المدمج بالشعار وبدون الملاحظة لتوفير المساحة
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
                        const Text(
                          'مرحباً بك في نظام إدارة معرضك',
                          style: TextStyle(
                            color: AppTheme.royalGold,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
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
              childAspectRatio: 1.15,
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

                // 4. ورشة المنجد
                StatCard(
                  title: 'ورشة المنجد',
                  value: '$upholstererRemainingPieces قطعة بالتشطيب',
                  icon: Icons.chair_alt_rounded,
                  color: Colors.purple.shade700,
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
          ],
        ),
      ),
    );
  }
}
