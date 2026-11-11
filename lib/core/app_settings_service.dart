import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

/// خدمة إدارة إعدادات التطبيق العامة (مثل تفعيل البصمة) وحفظها في قاعدة البيانات المحلية
class AppSettingsService {
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricPromptedKey = 'biometric_prompted';

  static Future<String?> getSetting(String key) async {
    final db = await DBHelper.instance.database;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value']?.toString();
  }

  static Future<void> setSetting(String key, String value) async {
    final db = await DBHelper.instance.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<bool> isBiometricEnabled() async {
    final val = await getSetting(_biometricEnabledKey);
    return val == 'true';
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    await setSetting(_biometricEnabledKey, enabled ? 'true' : 'false');
  }

  static Future<bool> wasBiometricPrompted() async {
    final val = await getSetting(_biometricPromptedKey);
    return val == 'true';
  }

  static Future<void> markBiometricPrompted() async {
    await setSetting(_biometricPromptedKey, 'true');
  }

  static Future<bool> isBiometricHardwareSupported() async {
    if (kIsWeb) return false;
    try {
      final auth = LocalAuthentication();
      return await auth.canCheckBiometrics || await auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }
}

