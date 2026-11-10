import 'package:flutter/foundation.dart';

/// نظام مركزي لإرسال واستقبال إشارات التحديث الفوري بين جميع شاشات التطبيق
class AppEvents {
  static final AppEvents instance = AppEvents._();
  AppEvents._();

  /// منبه التحديث الذي تشترك فيه جميع الشاشات
  final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  /// استدعاء هذا التابع يُحدّث كل الشاشات فوراً دون أي تأخير
  void notifyAll() {
    refreshNotifier.value++;
  }
}

