import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../components/app_update_banner.dart';
import '../core/app_events.dart';
import '../core/app_notification.dart';
import '../core/app_settings_service.dart';
import '../core/app_theme.dart';
import '../core/app_update_service.dart';
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

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GlobalKey<ManagementHubScreenState> _managementHubKey = GlobalKey<ManagementHubScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      DashboardScreen(onNavigateTab: _handleNavigate),
      const WaitingOrdersScreen(),
      const DeliveredOrdersScreen(),
      const UpholstererScreen(),
      ManagementHubScreen(key: _managementHubKey, initialTabIndex: 0),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStartupPrompts());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForAppUpdatesSilently();
    }
  }

  Future<void> _runStartupPrompts() async {
    await _checkFirstLaunchBiometricPrompt();
    if (!mounted) return;
    await _checkForAppUpdatesSilently();
  }

  Future<void> _checkForAppUpdatesSilently() async {
    final update = await AppUpdateService.checkForUpdate(silent: true);
    if (update != null && mounted) {
      AppUpdateBanner.show(context, update);
    }
  }

  Future<void> _checkFirstLaunchBiometricPrompt() async {
    final alreadyPrompted = await AppSettingsService.wasBiometricPrompted();
    if (alreadyPrompted) return;

    final alreadyEnabled = await AppSettingsService.isBiometricEnabled();
    if (alreadyEnabled) {
      await AppSettingsService.markBiometricPrompted();
      return;
    }

    final supported = await AppSettingsService.isBiometricHardwareSupported();
    if (!supported) {
      await AppSettingsService.markBiometricPrompted();
      return;
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryNavy, size: 28),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'تأمين التطبيق بالبصمة',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
              ),
            ),
          ],
        ),
        content: const Text(
          'مرحباً بك! هل ترغب في تفعيل الحماية ببصمة الإصبع عند فتح البرنامج لحماية بيانات المعرض والعملاء؟\n\nيمكنك تعديل هذا الإعداد في أي وقت من صفحة الإعدادات.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await AppSettingsService.markBiometricPrompted();
              if (dCtx.mounted) Navigator.pop(dCtx);
            },
            child: const Text('الإعداد لاحقاً', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: AppTheme.royalGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              try {
                final auth = LocalAuthentication();
                final didAuth = await auth.authenticate(
                  localizedReason: 'قم بتأكيد بصمة الإصبع لتفعيل الحماية',
                  options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
                );
                if (didAuth) {
                  await AppSettingsService.setBiometricEnabled(true);
                  await AppSettingsService.markBiometricPrompted();
                  if (dCtx.mounted) Navigator.pop(dCtx);
                  if (mounted) {
                    AppNotification.showSuccess(context, 'تم تفعيل الدخول بالبصمة بنجاح');
                  }
                }
              } catch (_) {
                await AppSettingsService.markBiometricPrompted();
                if (dCtx.mounted) Navigator.pop(dCtx);
              }
            },
            icon: const Icon(Icons.fingerprint_rounded, size: 20),
            label: const Text('تفعيل البصمة الآن', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
