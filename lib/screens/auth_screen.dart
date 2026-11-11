import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../components/app_logo.dart';
import '../core/app_theme.dart';
import '../core/app_version.dart';
import 'main_nav_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;
  bool _authFailed = false;
  String _statusMsg = 'يرجى تأكيد بصمة الإصبع للدخول إلى النظام';

  @override
  void initState() {
    super.initState();
    // تشغيل التحقق فوراً بمجرد رسم الشاشة الأولى بدون أي تأخير
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating || !mounted) return;
    setState(() {
      _isAuthenticating = true;
      _authFailed = false;
      _statusMsg = 'جاري التحقق من الهوية...';
    });

    try {
      final bool canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) {
        _goToHome();
        return;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'قم بمسح بصمة الإصبع أو تأكيد قفل الشاشة للدخول إلى نظام الألفي',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;

      if (didAuthenticate) {
        _goToHome();
      } else {
        setState(() {
          _isAuthenticating = false;
          _authFailed = true;
          _statusMsg = 'لم يكتمل التحقق بالبصمة، اضغط بالأسفل للمحاولة مرة أخرى.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _authFailed = true;
        _statusMsg = 'تعذر فتح مستشعر البصمة حالياً، حاول مرة أخرى.';
      });
    }
  }

  void _goToHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainNavigationScreen(),
        transitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryNavy,
              Color(0xFF142844),
              Color(0xFF0E1D33),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: AppTheme.royalGold.withValues(alpha: 0.45),
                        width: 2,
                      ),
                    ),
                    child: const AppLogo(size: 108),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'نظام الألفي لإدارة المعرض',
                    style: TextStyle(
                      color: AppTheme.royalGold,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'إدارة الأثاث والمخازن والطلبيات • ${AppVersion.displayVersion}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // بطاقة حالة التحقق بالبصمة
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 360),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _authFailed
                            ? Colors.orange.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.fingerprint_rounded,
                          size: 56,
                          color: _authFailed ? Colors.orangeAccent : AppTheme.royalGold,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _statusMsg,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.royalGold,
                              foregroundColor: AppTheme.primaryNavy,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isAuthenticating ? null : _authenticate,
                            icon: _isAuthenticating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: AppTheme.primaryNavy,
                                    ),
                                  )
                                : const Icon(Icons.fingerprint_rounded, size: 24),
                            label: Text(
                              _isAuthenticating
                                  ? 'بانتظار تأكيد البصمة...'
                                  : (_authFailed ? 'إعادة المحاولة بالبصمة' : 'تأكيد الدخول بالبصمة'),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
