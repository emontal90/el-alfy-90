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
  int waitingOrders = 0;
  int deliveredOrders = 0;
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
    final wait = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM orders WHERE status = 'waiting'")) ?? 0;
    final deliv = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM orders WHERE status = 'delivered'")) ?? 0;
    final uph = Sqflite.firstIntValue(await db.rawQuery('SELECT SUM(total_sent - received_qty) FROM upholsterer_batches')) ?? 0;

    if (mounted) {
      setState(() {
        customersCount = cust;
        categoriesCount = cats;
        totalStock = stock;
        waitingOrders = wait;
        deliveredOrders = deliv;
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primaryNavy, Color(0xFF2B5282)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مرحباً بك في نظام إدارة معرضك', style: TextStyle(color: AppTheme.royalGold, fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('ملاحظة: الطلبات في قائمة الانتظار لا تُخصم من رصيد المخزن إلا بعد الضغط على زر (تم التسليم).', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                StatCard(
                  title: 'قائمة الانتظار',
                  value: '$waitingOrders أوردر',
                  icon: Icons.pending_actions_rounded,
                  color: Colors.orange.shade800,
                  onTap: () => widget.onNavigateTab?.call(1),
                ),
                StatCard(
                  title: 'تم التسليم',
                  value: '$deliveredOrders أوردر',
                  icon: Icons.task_alt_rounded,
                  color: Colors.green.shade700,
                  onTap: () => widget.onNavigateTab?.call(2),
                ),
                StatCard(
                  title: 'مخزن المعرض',
                  value: '$totalStock طقم جاهز',
                  icon: Icons.storefront_rounded,
                  color: AppTheme.primaryNavy,
                  onTap: () => widget.onNavigateTab?.call(4, managementSubTab: 0),
                ),
                StatCard(
                  title: 'ورشة المنجد',
                  value: '$upholstererRemainingPieces قطعة بالتشطيب',
                  icon: Icons.chair_alt_rounded,
                  color: Colors.purple.shade700,
                  onTap: () => widget.onNavigateTab?.call(3),
                ),
                StatCard(
                  title: 'سجل العملاء',
                  value: '$customersCount عميل',
                  icon: Icons.people_alt_rounded,
                  color: Colors.teal.shade700,
                  onTap: () => widget.onNavigateTab?.call(4, managementSubTab: 2),
                ),
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
