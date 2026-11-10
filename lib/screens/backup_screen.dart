import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path/path.dart' as p;
import '../components/app_logo.dart';
import '../components/distinctive_refresh_button.dart';
import '../core/app_events.dart';
import '../core/app_notification.dart';
import '../core/app_theme.dart';
import '../core/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<FileSystemEntity> _backups = [];
  String _dbSize = '0 KB';
  int _archivedOrdersCount = 0;
  bool _isLoading = false;

  // فترة الأرشفة المختارة (بالشهور)
  int _selectedArchiveMonths = 6;
  int _eligibleForArchiveCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAllInfo();
    AppEvents.instance.refreshNotifier.addListener(_loadAllInfo);
  }

  @override
  void dispose() {
    AppEvents.instance.refreshNotifier.removeListener(_loadAllInfo);
    super.dispose();
  }

  Future<void> _loadAllInfo() async {
    setState(() => _isLoading = true);
    final backups = await BackupService.listBackups();
    final dbSize = await BackupService.getDatabaseSize();
    final archivedCount = await BackupService.getTotalArchivedOrdersCount();
    final eligible = await BackupService.getArchivableOrdersCount(_selectedArchiveMonths);

    if (mounted) {
      setState(() {
        _backups = backups;
        _dbSize = dbSize;
        _archivedOrdersCount = archivedCount;
        _eligibleForArchiveCount = eligible;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateEligibleCount(int months) async {
    setState(() => _selectedArchiveMonths = months);
    final count = await BackupService.getArchivableOrdersCount(months);
    if (mounted) {
      setState(() => _eligibleForArchiveCount = count);
    }
  }

  // 1. إنشاء نسخة احتياطية يدوية
  Future<void> _createManualBackup() async {
    setState(() => _isLoading = true);
    final res = await BackupService.createBackup(isAuto: false);
    await _loadAllInfo();
    if (mounted) {
      if (res.startsWith('فشل')) {
        AppNotification.showError(context, res);
      } else {
        AppNotification.showSuccess(context, 'تم إنشاء النسخة الاحتياطية اليدوية وضغط البيانات بنجاح');
      }
    }
  }

  // 2. تنظيف الكاش وضغط قاعدة البيانات
  Future<void> _cleanCacheAndVacuum() async {
    setState(() => _isLoading = true);
    final msg = await BackupService.clearAppCache();
    await _loadAllInfo();
    if (mounted) {
      AppNotification.showSuccess(context, msg);
    }
  }

  // 3. تأكيد وتنفيذ الاستعادة
  Future<void> _confirmAndRestore(FileSystemEntity file) async {
    final fileName = p.basename(file.path);
    final date = file.statSync().modified;
    final dateStr = intl.DateFormat('yyyy-MM-dd HH:mm').format(date);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('تأكيد استعادة النسخة الاحتياطية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'تحذير هام:\nاستعادة هذه النسخة سيستبدل جميع البيانات الحالية للبرنامج بالبيانات المحفوظة في هذه النسخة بتاريخ ($dateStr).\n\nاسم الملف: $fileName\n\nهل أنت متأكد من رغبتك في المتابعة؟',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('نعم، استعادة الآن'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final ok = await BackupService.restoreBackup(file.path);
      await _loadAllInfo();
      if (mounted) {
        if (ok) {
          AppNotification.showSuccess(context, 'تمت استعادة البيانات بنجاح وتحديث كافة الشاشات');
        } else {
          AppNotification.showError(context, 'فشلت الاستعادة، يرجى التأكد من صلاحيات الملف');
        }
      }
    }
  }

  // 4. حذف نسخة احتياطية قديمة
  Future<void> _deleteBackup(FileSystemEntity file) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text('تأكيد حذف النسخة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('هل أنت متأكد من حذف النسخة الاحتياطية "${p.basename(file.path)}" من الذاكرة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('حذف النسخة'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await file.delete();
        await _loadAllInfo();
        if (mounted) {
          AppNotification.showError(context, 'تم حذف ملف النسخة الاحتياطية بنجاح');
        }
      } catch (_) {}
    }
  }

  // 5. الأرشفة الذكية لفترة معينة
  Future<void> _performSmartArchive() async {
    if (_eligibleForArchiveCount <= 0) {
      AppNotification.showInfo(
        context,
        'لا توجد طلبات مسلّمة أقدم من $_selectedArchiveMonths شهر لأرشفتها.',
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.archive_outlined, color: AppTheme.primaryNavy, size: 28),
            SizedBox(width: 8),
            Text('تأكيد الأرشفة الذكية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'سيتم الآن أرشفة عدد ($_eligibleForArchiveCount) أوردر تم تسليمهم قديماً (أقدم من $_selectedArchiveMonths شهر).\n\n'
          'مميزات العملية:\n'
          '✓ يتم أخذ نسخة احتياطية كاملة وتلقائية قبل البدء.\n'
          '✓ يتم نقل الطلبات القديمة لسجل الأرشيف وحفظها للأبد.\n'
          '✓ يتم ضغط قاعدة البيانات لتسريع التصفح وتوفير المساحة.\n'
          '✓ لن يتم المساس برصيد المخزن أو بطلبات قائمة الانتظار نهائياً.\n\n'
          'هل تريد بدء عملية الأرشفة الآن؟',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: AppTheme.royalGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('بدء الأرشفة وضغط البيانات'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final count = await BackupService.archiveOrders(_selectedArchiveMonths);
      await _loadAllInfo();
      if (mounted) {
        if (count > 0) {
          AppNotification.showSuccess(
            context,
            'تمت أرشفة $count أوردر بنجاح وإنشاء نسخة احتياطية وقائية وضغط الداتابيز!',
          );
        } else {
          AppNotification.showError(context, 'حدث خطأ أثناء تنفيذ عملية الأرشفة');
        }
      }
    }
  }

  // 6. استرجاع كل الطلبات من الأرشيف
  Future<void> _restoreArchivedOrders() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.unarchive, color: Colors.blue, size: 28),
            SizedBox(width: 8),
            Text('استرجاع الأوردرات المؤرشفة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل تريد إعادة جميع الطلبات المؤرشفة ($_archivedOrdersCount أوردر) إلى قائمة الطلبات المسلّمة النشطة في البرنامج؟',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('تأكيد الاسترجاع'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final count = await BackupService.restoreAllArchivedOrders();
      await _loadAllInfo();
      if (mounted) {
        AppNotification.showSuccess(context, 'تمت استعادة $count أوردر من الأرشيف إلى قائمة المسلّم');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            AppLogo(size: 34),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'النسخ الاحتياطي والأرشفة الذكية',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: const [
          DistinctiveRefreshButton(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. بطاقات الإحصائيات والمعلومات السريعة
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.data_usage_rounded,
                        title: 'حجم قاعدة البيانات',
                        value: _dbSize,
                        color: Colors.blue.shade700,
                        subtitle: 'مضغوطة وخفيفة',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.backup_rounded,
                        title: 'النسخ الاحتياطية',
                        value: '${_backups.length} نسخة',
                        color: AppTheme.primaryNavy,
                        subtitle: 'محفوظة على الجهاز',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.inventory_2_outlined,
                        title: 'الطلبات بالأرشيف',
                        value: '$_archivedOrdersCount أوردر',
                        color: Colors.brown.shade600,
                        subtitle: 'محفوظة بأمان',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. أزرار الإجراءات السريعة
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: AppTheme.royalGold,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _createManualBackup,
                        icon: const Icon(Icons.add_to_photos_rounded),
                        label: const Text(
                          'إنشاء نسخة احتياطية الآن',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryNavy,
                          side: const BorderSide(color: AppTheme.primaryNavy),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _cleanCacheAndVacuum,
                        icon: const Icon(Icons.cleaning_services_rounded),
                        label: const Text(
                          'تنظيف الكاش والضغط',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 3. قسم الأرشفة الذكية
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppTheme.royalGold.withValues(alpha: 0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_fix_high_rounded, color: AppTheme.primaryNavy, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'الأرشفة الذكية للطلبات القديمة',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'تتيح لك الأرشفة الذكية نقل الطلبات التي تم تسليمها قديماً إلى سجل الأرشيف لتسريع التطبيق وتوفير المساحة لشغل سنوات قادمة، مع حفظ نسخة احتياطية تلقائياً قبل البدء.',
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                        const SizedBox(height: 14),

                        // اختيار فترة الأرشفة
                        const Text(
                          'اختر فترة الأرشفة للطلبات المسلّمة:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _PeriodOptionChip(
                              label: 'أقدم من 3 شهور',
                              months: 3,
                              isSelected: _selectedArchiveMonths == 3,
                              onSelected: () => _updateEligibleCount(3),
                            ),
                            _PeriodOptionChip(
                              label: 'أقدم من 6 شهور',
                              months: 6,
                              isSelected: _selectedArchiveMonths == 6,
                              onSelected: () => _updateEligibleCount(6),
                            ),
                            _PeriodOptionChip(
                              label: 'أقدم من 9 شهور',
                              months: 9,
                              isSelected: _selectedArchiveMonths == 9,
                              onSelected: () => _updateEligibleCount(9),
                            ),
                            _PeriodOptionChip(
                              label: 'أقدم من 12 شهر (سنة)',
                              months: 12,
                              isSelected: _selectedArchiveMonths == 12,
                              onSelected: () => _updateEligibleCount(12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // حالة الطلبات المؤهلة
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _eligibleForArchiveCount > 0 ? Colors.amber.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _eligibleForArchiveCount > 0 ? Colors.amber.shade300 : Colors.green.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _eligibleForArchiveCount > 0 ? Icons.info_outline : Icons.check_circle_outline,
                                color: _eligibleForArchiveCount > 0 ? Colors.brown : Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _eligibleForArchiveCount > 0
                                      ? 'يوجد حالياً ($_eligibleForArchiveCount) أوردر مسلّم أقدم من $_selectedArchiveMonths شهر مؤهل للأرشفة.'
                                      : 'لا توجد أوردرات مسلّمة أقدم من $_selectedArchiveMonths شهر حالياً.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _eligibleForArchiveCount > 0 ? Colors.brown : Colors.green.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // زر تنفيذ الأرشفة
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryNavy,
                                  foregroundColor: AppTheme.royalGold,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _eligibleForArchiveCount > 0 ? _performSmartArchive : null,
                                icon: const Icon(Icons.archive_rounded),
                                label: Text(
                                  'أرشفة ($_eligibleForArchiveCount) أوردر الآن',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ),
                            if (_archivedOrdersCount > 0) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue.shade800,
                                ),
                                onPressed: _restoreArchivedOrders,
                                icon: const Icon(Icons.unarchive_rounded, size: 18),
                                label: const Text('استرجاع الأرشيف', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 4. قائمة النسخ الاحتياطية المتوفرة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.folder_shared_rounded, color: AppTheme.primaryNavy, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'سجل النسخ الاحتياطية على الموبايل والكمبيوتر',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: 'تحديث القائمة',
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _loadAllInfo,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (kIsWeb)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ملاحظة: في بيئة المتصفح (Web)، يتم تخزين قاعدة البيانات والنسخ محلياً في IndexedDB بشكل تلقائي.',
                      style: TextStyle(color: AppTheme.primaryNavy),
                    ),
                  )
                else if (_backups.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Center(
                      child: Text(
                        'لا توجد نسخ احتياطية مسجلة بعد.\nاضغط على (إنشاء نسخة احتياطية الآن) بالأعلى لحفظ أول نسخة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  )
                else
                  ..._backups.map((file) {
                    final name = p.basename(file.path);
                    final stat = file.statSync();
                    final date = stat.modified;
                    final sizeKb = (stat.size / 1024).toStringAsFixed(1);
                    final isAuto = name.startsWith('auto_backup_');
                    final isArchive = name.startsWith('archive_backup_');

                    String tag = 'نسخة يدوية';
                    Color tagColor = AppTheme.primaryNavy;
                    Color tagBg = Colors.blue.shade50;

                    if (isAuto) {
                      tag = 'نسخة يومية تلقائية';
                      tagColor = Colors.green.shade800;
                      tagBg = Colors.green.shade50;
                    } else if (isArchive) {
                      tag = 'نسخة أرشيف وقائية';
                      tagColor = Colors.brown.shade800;
                      tagBg = Colors.amber.shade50;
                    }

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: tagBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isAuto
                                    ? Icons.schedule_rounded
                                    : (isArchive ? Icons.archive : Icons.save_rounded),
                                color: tagColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: tagBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          tag,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: tagColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$sizeKb KB',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '📅 ${intl.DateFormat('yyyy-MM-dd HH:mm').format(date)}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'حذف هذه النسخة',
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () => _deleteBackup(file),
                            ),
                            const SizedBox(width: 4),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryNavy,
                                foregroundColor: AppTheme.royalGold,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onPressed: () => _confirmAndRestore(file),
                              icon: const Icon(Icons.restore_rounded, size: 16),
                              label: const Text('استعادة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 30),
              ],
            ),
    );
  }
}

/// بطاقة إحصائيات صغيرة
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

/// زر اختيار فترة الأرشفة
class _PeriodOptionChip extends StatelessWidget {
  final String label;
  final int months;
  final bool isSelected;
  final VoidCallback onSelected;

  const _PeriodOptionChip({
    required this.label,
    required this.months,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.primaryNavy,
      labelStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: isSelected ? AppTheme.royalGold : Colors.black87,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
