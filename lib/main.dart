import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/app_theme.dart';
import 'core/db_helper.dart';
import 'core/backup_service.dart';
import 'screens/auth_screen.dart';
import 'screens/main_nav_screen.dart';
import 'core/platform_init.dart';

/// تم إيقاف البصمة مؤقتاً للتجربة المحلية على الكمبيوتر.
/// لإعادة تفعيل البصمة لاحقاً: غيّر القيمة إلى true
const bool useBiometricAuth = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDesktopDatabase();
  await DBHelper.instance.database;

  runApp(const FurnitureApp());

  // تنظيف الكاش الذكي والصيانة الدورية في الخلفية بدون أي تأخير على فتح البرنامج
  if (!kIsWeb) {
    BackupService.performSmartStartupMaintenance();
  }
}

class FurnitureApp extends StatelessWidget {
  const FurnitureApp({super.key});

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
      home: useBiometricAuth ? const AuthScreen() : const MainNavigationScreen(),
    );
  }
}
