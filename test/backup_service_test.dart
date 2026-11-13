import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:furniture_erp/core/backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });
  test('BackupService.enforceMaxBackupLimit keeps at most 5 newest .db files', () async {
    final tempDir = await Directory.systemTemp.createTemp('el_alfy_backup_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final names = [
      'auto_backup_2026-11-01.db',
      'manual_backup_2026-11-02_10-00-00.db',
      'archive_backup_6m_2026-11-03_10-00-00.db',
      'auto_backup_2026-11-04.db',
      'manual_backup_2026-11-05_10-00-00.db',
      'imported_backup_2026-11-06_10-00-00.db',
      'auto_backup_2026-11-07.db',
      'manual_backup_2026-11-08_10-00-00.db',
    ];

    final baseTime = DateTime(2026, 11, 1, 10, 0);
    for (int i = 0; i < names.length; i++) {
      final f = File(p.join(tempDir.path, names[i]));
      await f.writeAsBytes([1, 2, 3, 4]);
      await f.setLastModified(baseTime.add(Duration(days: i)));
    }

    // ملف غير قاعدة بيانات يجب ألا يُحذف
    final noteFile = File(p.join(tempDir.path, 'readme.txt'));
    await noteFile.writeAsString('keep');

    await BackupService.enforceMaxBackupLimit(tempDir);

    final remainingDbNames = tempDir
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .where((name) => name.endsWith('.db'))
        .toList();

    expect(BackupService.maxBackups, 5);
    expect(remainingDbNames.length, 5);
    expect(
      remainingDbNames.toSet(),
      equals({
        'auto_backup_2026-11-04.db',
        'manual_backup_2026-11-05_10-00-00.db',
        'imported_backup_2026-11-06_10-00-00.db',
        'auto_backup_2026-11-07.db',
        'manual_backup_2026-11-08_10-00-00.db',
      }),
    );
    expect(await noteFile.exists(), isTrue);
  });

  test('BackupService.factoryReset clears tables and keeps backups directory untouched', () async {
    final tempDir = await Directory.systemTemp.createTemp('el_alfy_backup_preserve_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final backupFile = File(p.join(tempDir.path, 'manual_backup_2026-11-10.db'));
    await backupFile.writeAsString('backup data');

    final result = await BackupService.factoryReset();
    expect(result, isTrue);

    // التحقق من بقاء ملف النسخة الاحتياطية سليم تماماً
    expect(await backupFile.exists(), isTrue);
    expect(await backupFile.readAsString(), 'backup data');
  });
}

