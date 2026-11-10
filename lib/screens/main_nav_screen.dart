import 'package:flutter/material.dart';
import '../core/app_events.dart';
import '../core/app_theme.dart';
import 'dashboard_screen.dart';
import 'waiting_orders_screen.dart';
import 'delivered_orders_screen.dart';
import 'upholsterer_screen.dart';
import 'new_order_screen.dart';
import 'management/management_hub.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<ManagementHubScreenState> _managementHubKey = GlobalKey<ManagementHubScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(onNavigateTab: _handleNavigate),
      const WaitingOrdersScreen(),
      const DeliveredOrdersScreen(),
      const UpholstererScreen(),
      ManagementHubScreen(key: _managementHubKey, initialTabIndex: 0),
    ];
  }

  void _handleNavigate(int tabIndex, {int? managementSubTab}) {
    setState(() {
      _currentIndex = tabIndex;
    });
    if (tabIndex == 4 && managementSubTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _managementHubKey.currentState?.switchToTab(managementSubTab);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // استخدام IndexedStack للحفاظ على الشاشات في الذاكرة وتسريع التنقل اللحظي بدون أي تأخير أو إعادة تحميل
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: (_currentIndex == 3 || _currentIndex == 4)
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: AppTheme.royalGold,
              onPressed: () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewOrderScreen()));
                if (res == true) {
                  AppEvents.instance.notifyAll();
                  // الانتقال التلقائي المباشر إلى صفحة قائمة الانتظار بعد إدخال طلب عميل جديد
                  setState(() {
                    _currentIndex = 1;
                  });
                }
              },
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('طلب جديد', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          // تنقل فوري سلس بدون تشغيل استعلامات غير ضرورية
          setState(() => _currentIndex = idx);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.hourglass_top_rounded), label: 'الانتظار'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline_rounded), label: 'تم التسليم'),
          NavigationDestination(icon: Icon(Icons.handyman_rounded), label: 'المنجد'),
          NavigationDestination(icon: Icon(Icons.inventory_2_rounded), label: 'البيانات والمخزن'),
        ],
      ),
    );
  }
}
