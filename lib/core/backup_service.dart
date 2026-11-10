import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/painting.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'app_events.dart';
import 'db_helper.dart';

class BackupService {
  /// مجلد حفظ النسخ الاحتياطية على الموبايل والكمبيوتر
  static Future<Directory> getBackupDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(dir.path, 'FurnitureBackups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// مسار ملف قاعدة البيانات الفعلي
  static Future<File> getDatabaseFile() async {
    final dbPath = await getDatabasesPath();
    return File(p.join(dbPath, 'furniture_erp.db'));
  }

  /// حجم قاعدة البيانات الفعلي المنسق (بالكيلوبايت أو الميجابايت)
  static Future<String> getDatabaseSize() async {
    try {
      final file = await getDatabaseFile();
      if (await file.exists()) {
        final bytes = await file.length();
        if (bytes < 1024 * 1024) {
          return '${(bytes / 1024).toStringAsFixed(1)} KB';
        } else {
          return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
        }
      }
    } catch (_) {}
    return '0 KB';
  }

  /// إنشاء نسخة احتياطية (يدوية أو تلقائية أو قبل الأرشفة)
  static Future<String> createBackup({
    bool isAuto = false,
    String? prefix,
  }) async {
    if (kIsWeb) return 'النسخ الاحتياطي غير متاح على الويب';

    try {
      // 1. ضغط وتحسين قاعدة البيانات أولاً لتكون النسخة الاحتياطية بأصغر حجم ممكن
      final db = await DBHelper.instance.database;
      try {
        await db.execute('PRAGMA optimize');
        await db.execute('VACUUM');
      } catch (_) {}

      final srcFile = await getDatabaseFile();
      if (!await srcFile.exists()) return 'قاعدة البيانات غير موجودة بعد';

      final backupDir = await getBackupDir();
      final dateStr = intl.DateFormat('yyyy-MM-dd').format(DateTime.now());
      final timeStr = intl.DateFormat('HH-mm-ss').format(DateTime.now());

      String fileName;
      if (prefix != null && prefix.isNotEmpty) {
        fileName = '${prefix}_${dateStr}_$timeStr.db';
      } else if (isAuto) {
        fileName = 'auto_backup_$dateStr.db';
      } else {
        fileName = 'manual_backup_${dateStr}_$timeStr.db';
      }

      final destPath = p.join(backupDir.path, fileName);
      await srcFile.copy(destPath);

      // إدارة النسخ التلقائية القديمة والاحتفاظ بآخر 30 نسخة يومية فقط
      if (isAuto) {
        await _cleanOldAutoBackups(backupDir);
      }

      return destPath;
    } catch (e) {
      return 'فشل إنشاء النسخة الاحتياطية: $e';
    }
  }

  /// التحقق من وجود نسخة احتياطية لليوم وإنشائها تلقائياً
  static Future<void> performDailyAutoBackup() async {
    if (kIsWeb) return;
    try {
      final backupDir = await getBackupDir();
      final dateStr = intl.DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayBackup = File(p.join(backupDir.path, 'auto_backup_$dateStr.db'));
      if (!await todayBackup.exists()) {
        await createBackup(isAuto: true);
      }
    } catch (_) {}
  }

  /// حذف النسخ اليومية التلقائية الأقدم من 30 يوماً لتوفير المساحة، مع الاحتفاظ بجميع النسخ اليدوية
  static Future<void> _cleanOldAutoBackups(Directory backupDir) async {
    try {
      final files = backupDir.listSync().whereType<File>().toList();
      final autoBackups = files.where((f) => p.basename(f.path).startsWith('auto_backup_')).toList();
      if (autoBackups.length > 30) {
        autoBackups.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        for (int i = 30; i < autoBackups.length; i++) {
          await autoBackups[i].delete();
        }
      }
    } catch (_) {}
  }

  /// جلب قائمة جميع النسخ الاحتياطية مرتبة من الأحدث للأقدم
  static Future<List<FileSystemEntity>> listBackups() async {
    if (kIsWeb) return [];
    try {
      final dir = await getBackupDir();
      final files = dir.listSync().where((f) => f.path.endsWith('.db')).toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return files;
    } catch (_) {
      return [];
    }
  }

  /// استعادة نسخة احتياطية بأمان مع إغلاق وإعادة فتح الاتصال وتحديث الشاشات
  static Future<bool> restoreBackup(String backupFilePath) async {
    if (kIsWeb) return false;
    try {
      final backupFile = File(backupFilePath);
      if (!await backupFile.exists() || await backupFile.length() == 0) {
        return false;
      }

      // 1. إغلاق اتصال قاعدة البيانات الحالي بأمان لمنع أي أقفال ملفات
      await DBHelper.instance.closeDatabase();

      // 2. نسخ ملف الباك آب فوق ملف الداتابيز الفعلي
      final destFile = await getDatabaseFile();
      await backupFile.copy(destFile.path);

      // 3. إعادة فتح اتصال قاعدة البيانات وتحديث الجداول
      final db = await DBHelper.instance.database;
      try {
        await db.execute('PRAGMA optimize');
        await db.execute('VACUUM');
      } catch (_) {}

      // 4. إشعار جميع الشاشات بالتحديث الفوري
      AppEvents.instance.notifyAll();
      return true;
    } catch (e) {
      // محاولة إعادة فتح قاعدة البيانات في حال حدث أي خطأ
      await DBHelper.instance.database;
      return false;
    }
  }

  /// تنظيف الكاش الذكي عند بدء التشغيل دون التسبب في أي بطء لواجهة المستخدم
  static void performSmartStartupMaintenance() {
    // تشغيل الصيانة في الخلفية بعد تحميل الشاشة بنجاح
    Future.microtask(() async {
      try {
        // تنظيف الكاش المؤقت
        final tempDir = await getTemporaryDirectory();
        if (tempDir.existsSync()) {
          for (var entity in tempDir.listSync(recursive: true)) {
            if (entity is File) {
              try {
                final stat = await entity.stat();
                // حذف الملفات المؤقتة الأقدم من 24 ساعة فقط
                if (DateTime.now().difference(stat.modified).inHours >= 24) {
                  await entity.delete();
                }
              } catch (_) {}
            }
          }
        }

        // تنظيف ذاكرة الصور
        PaintingBinding.instance.imageCache.clear();

        // فحص النسخة الاحتياطية اليومية التلقائية
        await performDailyAutoBackup();

        // تحسين وفهرسة قاعدة البيانات
        final db = await DBHelper.instance.database;
        await db.execute('PRAGMA optimize');
      } catch (_) {}
    });
  }

  /// تنظيف الكاش اليدوي وضغط قاعدة البيانات (VACUUM)
  static Future<String> clearAppCache() async {
    int totalDeletedBytes = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        for (var entity in tempDir.listSync(recursive: true)) {
          if (entity is File) {
            try {
              totalDeletedBytes += await entity.length();
              await entity.delete();
            } catch (_) {}
          }
        }
      }
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      final db = await DBHelper.instance.database;
      await db.execute('PRAGMA optimize');
      await db.execute('VACUUM');
    } catch (_) {}

    final kb = (totalDeletedBytes / 1024).toStringAsFixed(1);
    return 'تم تنظيف الكاش وضغط قاعدة البيانات بالكامل بنجاح ($kb KB)';
  }

  /// -------------------------------------------------------------------------
  /// الأرشفة الذكية (Smart Archiving)
  /// -------------------------------------------------------------------------

  /// حساب عدد الطلبات المؤهلة للأرشفة (الطلبات المسلّمة فقط الأقدم من X شهر)
  static Future<int> getArchivableOrdersCount(int months) async {
    try {
      final db = await DBHelper.instance.database;
      final threshold = DateTime.now().subtract(Duration(days: months * 30));
      final thresholdStr = intl.DateFormat('yyyy-MM-dd').format(threshold);

      final count = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM orders WHERE status = 'delivered' AND (delivery_date <= ? OR created_at <= ?)",
        [thresholdStr, thresholdStr],
      ));
      return count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// إجمالي عدد الطلبات المؤرشفة حالياً
  static Future<int> getTotalArchivedOrdersCount() async {
    try {
      final db = await DBHelper.instance.database;
      final count = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM archived_orders"));
      return count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// تنفيذ الأرشفة الذكية لطلبات فترة معينة (3، 6، 9، 12 شهر)
  static Future<int> archiveOrders(int months) async {
    try {
      final db = await DBHelper.instance.database;
      final threshold = DateTime.now().subtract(Duration(days: months * 30));
      final thresholdStr = intl.DateFormat('yyyy-MM-dd').format(threshold);
      final todayStr = intl.DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

      // جلب الطلبات المسلّمة الأقدم من الفترة المحددة
      final ordersToArchive = await db.query(
        'orders',
        where: "status = 'delivered' AND (delivery_date <= ? OR created_at <= ?)",
        whereArgs: [thresholdStr, thresholdStr],
      );

      if (ordersToArchive.isEmpty) return 0;

      // 1. إنشاء نسخة احتياطية وقائية قبل الأرشفة
      await createBackup(prefix: 'archive_backup_${months}m');

      // 2. نقل الطلبات لجدول الأرشيف
      final batch = db.batch();
      for (final o in ordersToArchive) {
        batch.insert('archived_orders', {
          'id': o['id'],
          'customer_id': o['customer_id'],
          'customer_name': o['customer_name'],
          'category_id': o['category_id'],
          'category_name': o['category_name'],
          'selected_components_json': o['selected_components_json'],
          'specs': o['specs'],
          'delivery_date': o['delivery_date'],
          'order_type': o['order_type'],
          'status': o['status'],
          'created_at': o['created_at'],
          'archived_at': todayStr,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        batch.delete('orders', where: 'id = ?', whereArgs: [o['id']]);
      }
      await batch.commit(noResult: true);

      // 3. ضغط قاعدة البيانات فوراً لاستعادة المساحة المحررة
      await db.execute('PRAGMA optimize');
      await db.execute('VACUUM');

      // 4. إشعار جميع الشاشات
      AppEvents.instance.notifyAll();

      return ordersToArchive.length;
    } catch (e) {
      return -1;
    }
  }

  /// استرجاع كل الطلبات من الأرشيف إلى قائمة الطلبات المسلّمة
  static Future<int> restoreAllArchivedOrders() async {
    try {
      final db = await DBHelper.instance.database;
      final archived = await db.query('archived_orders');
      if (archived.isEmpty) return 0;

      final batch = db.batch();
      for (final a in archived) {
        batch.insert('orders', {
          'customer_id': a['customer_id'],
          'customer_name': a['customer_name'],
          'category_id': a['category_id'],
          'category_name': a['category_name'],
          'selected_components_json': a['selected_components_json'],
          'specs': a['specs'],
          'delivery_date': a['delivery_date'],
          'order_type': a['order_type'],
          'status': 'delivered',
          'created_at': a['created_at'],
        });
      }
      batch.delete('archived_orders');
      await batch.commit(noResult: true);

      await db.execute('VACUUM');
      AppEvents.instance.notifyAll();
      return archived.length;
    } catch (_) {
      return -1;
    }
  }
}
