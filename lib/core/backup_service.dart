import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'app_events.dart';
import 'db_helper.dart';

class BackupService {
  static const int maxBackups = 5;
  static const MethodChannel _transferChannel =
      MethodChannel('com.example.furniture_erp/backup_transfer');
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

      // الاحتفاظ بآخر 5 نسخ احتياطية فقط وحذف الأقدم لمنع تضخم الملفات
      await enforceMaxBackupLimit(backupDir);

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
      } else {
        await enforceMaxBackupLimit(backupDir);
      }
    } catch (_) {}
  }

  /// التأكد من أن إجمالي ملفات النسخ الاحتياطية لا يتجاوز [maxCount] (5 ملفات افتراضياً) وحذف الأقدم
  static Future<void> enforceMaxBackupLimit(
    Directory backupDir, {
    int maxCount = maxBackups,
  }) async {
    try {
      if (!await backupDir.exists()) return;
      final dbFiles = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.db'))
          .toList();

      if (dbFiles.length <= maxCount) return;

      dbFiles.sort((a, b) {
        final modCmp = b.statSync().modified.compareTo(a.statSync().modified);
        if (modCmp != 0) return modCmp;
        return p.basename(b.path).compareTo(p.basename(a.path));
      });

      for (int i = maxCount; i < dbFiles.length; i++) {
        try {
          await dbFiles[i].delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// جلب قائمة جميع النسخ الاحتياطية مرتبة من الأحدث للأقدم (بحد أقصى 5 نسخ)
  static Future<List<FileSystemEntity>> listBackups() async {
    if (kIsWeb) return [];
    try {
      final dir = await getBackupDir();
      await enforceMaxBackupLimit(dir);
      final files = dir.listSync().where((f) => f.path.toLowerCase().endsWith('.db')).toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return files;
    } catch (_) {
      return [];
    }
  }

  /// التحقق من أن الملف المختار هو قاعدة بيانات SQLite صالحة لتطبيق الألفي
  static Future<bool> isValidBackupDatabase(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists() || await file.length() < 1024) {
        return false;
      }

      // 1. فحص ترويسة SQLite الرسمية: "SQLite format 3\0"
      const expectedHeader = [
        0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66,
        0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x33, 0x00,
      ];
      final raf = await file.open(mode: FileMode.read);
      try {
        final header = await raf.read(16);
        if (header.length < 16) return false;
        for (int i = 0; i < 16; i++) {
          if (header[i] != expectedHeader[i]) return false;
        }
      } finally {
        await raf.close();
      }

      // 2. التأكد من وجود الجداول الأساسية للتطبيق
      final testDb = await openReadOnlyDatabase(filePath);
      try {
        final rows = await testDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('orders', 'customers', 'categories')",
        );
        return rows.length == 3;
      } finally {
        await testDb.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// تصدير نسخة احتياطية إلى مجلد التنزيلات في الهاتف (تبقى محفوظة حتى لو حُذف التطبيق)
  static Future<String?> exportBackupToDownloads(String backupFilePath) async {
    if (kIsWeb) return null;
    final sourceFile = File(backupFilePath);
    if (!await sourceFile.exists()) {
      throw Exception('ملف النسخة الاحتياطية غير موجود');
    }

    final fileName = p.basename(sourceFile.path);
    if (Platform.isAndroid) {
      return await _transferChannel.invokeMethod<String>(
        'exportBackupToDownloads',
        {'path': sourceFile.path, 'fileName': fileName},
      );
    }

    // في نظام ويندوز: الحفظ في Downloads\ElAlfyBackups مع حد أقصى 5 نسخ
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.isNotEmpty) {
      final dlDir = Directory(p.join(userProfile, 'Downloads', 'ElAlfyBackups'));
      if (!await dlDir.exists()) {
        await dlDir.create(recursive: true);
      }
      final dest = File(p.join(dlDir.path, fileName));
      await sourceFile.copy(dest.path);
      await enforceMaxBackupLimit(dlDir);
      return dest.path;
    }

    return null;
  }

  /// إنشاء نسخة جديدة وتصديرها فوراً إلى مجلد التنزيلات
  static Future<String?> createAndExportBackupToDownloads() async {
    final createdPath = await createBackup(isAuto: false);
    if (createdPath.startsWith('فشل') || createdPath.startsWith('قاعدة') || createdPath.startsWith('النسخ')) {
      throw Exception(createdPath);
    }
    return await exportBackupToDownloads(createdPath);
  }

  /// مشاركة نسخة احتياطية خارج التطبيق (واتساب / تيليجرام / Google Drive ...)
  static Future<void> shareBackupFile(String backupFilePath) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw UnsupportedError('المشاركة المباشرة متاحة على أجهزة Android فقط.');
    }
    final sourceFile = File(backupFilePath);
    if (!await sourceFile.exists()) {
      throw Exception('ملف النسخة الاحتياطية غير موجود');
    }
    await _transferChannel.invokeMethod<void>(
      'shareBackupFile',
      {'path': sourceFile.path, 'fileName': p.basename(sourceFile.path)},
    );
  }

  /// اختيار ملف نسخة احتياطية (.db) من الهاتف واستعادته بأمان بعد التحقق من سلامته
  /// يعيد اسم الملف المستعاد أو `null` إذا ألغى المستخدم الاختيار
  static Future<String?> importAndRestoreExternalBackup() async {
    if (kIsWeb || !Platform.isAndroid) {
      throw UnsupportedError('الاستيراد من منتقي النظام متاح حالياً على Android.');
    }

    final pickedTempPath = await _transferChannel.invokeMethod<String>('pickBackupFile');
    if (pickedTempPath == null || pickedTempPath.isEmpty) {
      return null;
    }

    final tempFile = File(pickedTempPath);
    try {
      final valid = await isValidBackupDatabase(pickedTempPath);
      if (!valid) {
        throw Exception('الملف المختار لا يخص قاعدة بيانات نظام الألفي أو أنه تالف.');
      }

      // أخذ نسخة وقائية من البيانات الحالية قبل الاستبدال
      await createBackup(isAuto: false, prefix: 'pre_import_backup');

      final restored = await restoreBackup(pickedTempPath);
      if (!restored) {
        throw Exception('تعذر استعادة البيانات من الملف المختار.');
      }

      // حفظ نسخة من الملف المستورد ضمن سجل النسخ الاحتياطية (مع الالتزام بحد أقصى 5 نسخ)
      final backupDir = await getBackupDir();
      final dateStr = intl.DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final savedCopy = File(p.join(backupDir.path, 'imported_backup_$dateStr.db'));
      await tempFile.copy(savedCopy.path);
      await enforceMaxBackupLimit(backupDir);

      return p.basename(savedCopy.path);
    } finally {
      try {
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
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

  /// إعادة ضبط المصنع: تصفير وتفريغ جميع جداول قاعدة البيانات مع الحفاظ على ملفات النسخ الاحتياطية
  static Future<bool> factoryReset() async {
    try {
      final db = await DBHelper.instance.database;
      await db.transaction((txn) async {
        await txn.delete('orders');
        try { await txn.delete('archived_orders'); } catch (_) {}
        try { await txn.delete('customers'); } catch (_) {}
        try { await txn.delete('categories'); } catch (_) {}
        try { await txn.delete('upholsterer_batches'); } catch (_) {}
        try { await txn.delete('upholsterer_transactions'); } catch (_) {}
        try { await txn.delete('stock_movements'); } catch (_) {}
        try { await txn.delete('app_settings'); } catch (_) {}
      });

      try {
        await db.execute('PRAGMA optimize');
        await db.execute('VACUUM');
      } catch (_) {}

      AppEvents.instance.notifyAll();
      return true;
    } catch (_) {
      return false;
    }
  }
}
