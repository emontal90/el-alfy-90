import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/app_settings_service.dart';
import 'core/app_theme.dart';
import 'core/backup_service.dart';
import 'core/db_helper.dart';
import 'core/platform_init.dart';
import 'screens/auth_screen.dart';
import 'screens/main_nav_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDesktopDatabase();
  await DBHelper.instance.database;

  final bool biometricEnabled = await AppSettingsService.isBiometricEnabled();

  runApp(FurnitureApp(initialBiometricEnabled: biometricEnabled));

  // تنظيف الكاش الذكي والصيانة الدورية في الخلفية بدون أي تأخير على فتح البرنامج
  if (!kIsWeb) {
    BackupService.performSmartStartupMaintenance();
  }
}

class FurnitureApp extends StatelessWidget {
  final bool initialBiometricEnabled;

  const FurnitureApp({
    super.key,
    this.initialBiometricEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إدارة الموبيليا',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: initialBiometricEnabled ? const AuthScreen() : const MainNavigationScreen(),
    );
  }
}
