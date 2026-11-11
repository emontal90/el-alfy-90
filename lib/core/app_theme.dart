import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryNavy = Color(0xFF1E3A5F);
  static const Color royalGold = Color(0xFFD4AF37);
  static const Color bgSurface = Color(0xFFF8F9FA);

  /// هامش سفلي ذكي للنوافذ المنبثقة لتجنب تداخل الأزرار مع شريط التنقل بالهاتف أو لوحة المفاتيح
  static EdgeInsets modalSheetPadding(
    BuildContext context, {
    double horizontal = 16,
    double top = 20,
  }) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom > mq.viewPadding.bottom
        ? mq.viewInsets.bottom
        : mq.viewPadding.bottom;
    return EdgeInsets.only(
      left: horizontal,
      right: horizontal,
      top: top,
      bottom: bottomInset + 24,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryNavy,
        secondary: royalGold,
        surface: bgSurface,
      ),
      fontFamily: 'Roboto',
      cardTheme: CardThemeData(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        iconTheme: const WidgetStatePropertyAll(IconThemeData(size: 22)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? primaryNavy : Colors.grey.shade800,
            overflow: TextOverflow.ellipsis,
          );
        }),
      ),
      tabBarTheme: const TabBarThemeData(
        labelPadding: EdgeInsets.symmetric(horizontal: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
