import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../components/app_logo.dart';
import '../core/app_theme.dart';
import 'main_nav_screen.dart';

/// تم إيقاف البصمة مؤقتاً للتجربة المحلية على الكمبيوتر.
/// لإعادة تفعيل البصمة لاحقاً: غيّر القيمة إلى false
const bool bypassBiometrics = true;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  String _statusMsg = bypassBiometrics
      ? 'تم إيقاف البصمة مؤقتاً للتجربة المحلية'
      : 'يرجى تأكيد الهوية للدخول إلى النظام';

  @override
  void initState() {
    super.initState();
    if (bypassBiometrics) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToHome());
      return;
    }
    _authenticate();
  }

  Future<void> _authenticate() async {
    if (bypassBiometrics) {
      _goToHome();
      return;
    }
    try {
      final bool canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canCheck) {
        _goToHome();
        return;
      }
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'قم بمسح بصمة الإصبع للدخول لنظام إدارة الموبيليا',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (didAuthenticate) {
        _goToHome();
      } else {
        setState(() => _statusMsg = 'لم يتم التعرف على البصمة، حاول مرة أخرى.');
      }
    } catch (_) {
      _goToHome();
    }
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryNavy,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(size: 110),
              const SizedBox(height: 24),
              const Text(
                'نظام إدارة الموبيليا المتكامل',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                _statusMsg,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalGold,
                  foregroundColor: AppTheme.primaryNavy,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                onPressed: bypassBiometrics ? _goToHome : _authenticate,
                icon: const Icon(Icons.fingerprint, size: 28),
                label: const Text(
                  bypassBiometrics ? 'الدخول مباشرة (البصمة معطلة)' : 'تسجيل الدخول بالبصمة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
