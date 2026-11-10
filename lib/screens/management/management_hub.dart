import 'package:flutter/material.dart';
import '../../components/app_logo.dart';
import '../../components/distinctive_refresh_button.dart';
import 'customers_tab.dart';
import 'categories_tab.dart';
import 'showroom_stock_tab.dart';

class ManagementHubScreen extends StatelessWidget {
  const ManagementHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              AppLogo(size: 34),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'إدارة العملاء والأصناف والمخزن',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: const [
            DistinctiveRefreshButton(),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'العملاء'),
              Tab(icon: Icon(Icons.weekend), text: 'الأصناف ومكوناتها'),
              Tab(icon: Icon(Icons.warehouse), text: 'مخزن المعرض'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            CustomersTab(),
            CategoriesTab(),
            ShowroomStockTab(),
          ],
        ),
      ),
    );
  }
}
