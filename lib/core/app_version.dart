/// معلومات إصدار التطبيق الحالية (تُحدّث تلقائياً عند عمل Release جديد)
class AppVersion {
  static const String version = '1.0.5';
  static const int buildNumber = 6;

  static String get displayVersion => 'v$version';
  static String get fullVersion => 'v$version ($buildNumber)';
}
