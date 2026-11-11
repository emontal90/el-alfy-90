import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../components/app_logo.dart';
import '../components/app_update_dialog.dart';
import '../core/app_notification.dart';
import '../core/app_settings_service.dart';
import '../core/app_theme.dart';
import '../core/app_update_service.dart';
import '../core/app_version.dart';
import 'backup_screen.dart';

class SettingsHubScreen extends StatefulWidget {
  final int initialTabIndex;
  const SettingsHubScreen({super.key, this.initialTabIndex = 0});

  @override
  State<SettingsHubScreen> createState() => _SettingsHubScreenState();
}

class _SettingsHubScreenState extends State<SettingsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitleWithLogo(title: 'إعدادات النظام'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.tune_rounded), text: 'الإعدادات العامة'),
            Tab(icon: Icon(Icons.backup_rounded), text: 'النسخ الاحتياطي والكاش'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _GeneralSettingsTab(),
          BackupScreen(embedded: true),
        ],
      ),
    );
  }
}

class _GeneralSettingsTab extends StatefulWidget {
  const _GeneralSettingsTab();

  @override
  State<_GeneralSettingsTab> createState() => _GeneralSettingsTabState();
}

class _GeneralSettingsTabState extends State<_GeneralSettingsTab> {
  bool _biometricEnabled = false;
  bool _biometricSupported = true;
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await AppSettingsService.isBiometricEnabled();
    final supported = await AppSettingsService.isBiometricHardwareSupported();
    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _biometricSupported = supported;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (_isUpdating) return;

    if (value && !_biometricSupported) {
      AppNotification.showError(
        context,
        'هذا الجهاز لا يدعم مستشعر البصمة أو قفل الشاشة حالياً.',
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      if (value) {
        final auth = LocalAuthentication();
        final didAuth = await auth.authenticate(
          localizedReason: 'قم بمسح بصمة الإصبع لتأكيد تفعيل الحماية',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),
        );

        if (!didAuth) {
          if (mounted) {
            setState(() => _isUpdating = false);
            AppNotification.showError(context, 'لم يتم التحقق من البصمة، لم يُفعّل القفل.');
          }
          return;
        }
      }

      await AppSettingsService.setBiometricEnabled(value);
      await AppSettingsService.markBiometricPrompted();

      if (mounted) {
        setState(() {
          _biometricEnabled = value;
          _isUpdating = false;
        });
        AppNotification.showSuccess(
          context,
          value
              ? 'تم تفعيل الدخول ببصمة الإصبع بنجاح'
              : 'تم إلغاء قفل البصمة — سيفتح التطبيق مباشرة',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isUpdating = false);
        AppNotification.showError(context, 'تعذر التحقق من البصمة على هذا الجهاز.');
      }
    }
  }

  Future<void> _checkForUpdatesManually() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);

    try {
      final update = await AppUpdateService.checkForUpdate(silent: false);
      if (!mounted) return;
      setState(() => _isCheckingUpdate = false);

      if (update != null) {
        await AppUpdateDialog.show(context, update);
      } else {
        AppNotification.showSuccess(
          context,
          'تطبيقك محدث بالفعل على أحدث إصدار (${AppVersion.displayVersion}).',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCheckingUpdate = false);
      AppNotification.showError(
        context,
        'تعذر الاتصال بـ GitHub للتحقق من التحديثات. تأكد من اتصال الإنترنت.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // قسم الأمان وحماية التطبيق بالبصمة
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.primaryNavy.withValues(alpha: 0.12)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.security_rounded, color: AppTheme.primaryNavy, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'الأمان وحماية التطبيق',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: _biometricEnabled
                          ? Colors.green.withValues(alpha: 0.06)
                          : Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _biometricEnabled
                            ? Colors.green.withValues(alpha: 0.35)
                            : Colors.grey.withValues(alpha: 0.25),
                      ),
                    ),
                    child: SwitchListTile(
                      value: _biometricEnabled,
                      onChanged: _isUpdating ? null : _toggleBiometric,
                      activeThumbColor: AppTheme.primaryNavy,
                      activeTrackColor: AppTheme.royalGold.withValues(alpha: 0.65),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _biometricEnabled
                              ? AppTheme.primaryNavy
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.fingerprint_rounded,
                          color: _biometricEnabled ? AppTheme.royalGold : Colors.grey.shade700,
                          size: 26,
                        ),
                      ),
                      title: const Text(
                        'تفعيل الدخول بالبصمة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Text(
                        !_biometricSupported
                            ? 'الجهاز الحالي لا يدعم مستشعر البصمة'
                            : (_biometricEnabled
                                ? 'مفعّلة: يتطلب تأكيد البصمة عند فتح البرنامج'
                                : 'معطّلة: يفتح البرنامج مباشرة بدون بصمة'),
                        style: TextStyle(
                          fontSize: 12,
                          color: _biometricEnabled ? Colors.green.shade800 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // بطاقة معلومات التطبيق والإصدار والتحديثات
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.royalGold.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const AppLogo(size: 56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'نظام الألفي لإدارة المعرض',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'إدارة المخازن، المنجدين، وطلبات العملاء',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryNavy,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'الإصدار ${AppVersion.fullVersion}',
                                style: const TextStyle(
                                  color: AppTheme.royalGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryNavy,
                        side: BorderSide(color: AppTheme.primaryNavy.withValues(alpha: 0.35)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isCheckingUpdate ? null : _checkForUpdatesManually,
                      icon: _isCheckingUpdate
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.system_update_rounded, size: 20),
                      label: Text(
                        _isCheckingUpdate ? 'جارٍ التحقق من التحديثات...' : 'التحقق من التحديثات',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

