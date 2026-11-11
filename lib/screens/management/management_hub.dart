import 'package:flutter/material.dart';
import '../../components/app_logo.dart';
import '../../components/distinctive_refresh_button.dart';
import 'customers_tab.dart';
import 'categories_tab.dart';
import 'showroom_stock_tab.dart';

class ManagementHubScreen extends StatefulWidget {
  final int initialTabIndex;
  const ManagementHubScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ManagementHubScreen> createState() => ManagementHubScreenState();
}

class ManagementHubScreenState extends State<ManagementHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void didUpdateWidget(covariant ManagementHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      tabController.animateTo(widget.initialTabIndex.clamp(0, 2));
    }
  }

  void switchToTab(int index) {
    if (mounted && index >= 0 && index < tabController.length) {
      tabController.animateTo(index);
    }
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitleWithLogo(title: 'إدارة المخزن والأصناف والعملاء'),
        actions: const [
          DistinctiveRefreshButton(),
        ],
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(icon: Icon(Icons.warehouse_rounded), text: 'مخزن المعرض'),
            Tab(icon: Icon(Icons.weekend_rounded), text: 'الأصناف ومكوناتها'),
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'العملاء'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: const [
          ShowroomStockTab(),
          CategoriesTab(),
          CustomersTab(),
        ],
      ),
    );
  }
}
