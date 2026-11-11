import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/app_update_service.dart';
import '../core/app_version.dart';

class AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo update;

  const AppUpdateDialog({super.key, required this.update});

  static Future<void> show(BuildContext context, AppUpdateInfo update) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppUpdateDialog(update: update),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

enum _UpdateDialogStage {
  prompt,
  downloading,
  needsPermission,
  readyToInstall,
  error,
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  _UpdateDialogStage _stage = _UpdateDialogStage.prompt;
  double? _progress;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  bool _cancelled = false;
  String? _downloadedApkPath;
  String? _errorMessage;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _startDownloadAndInstall() async {
    if (kIsWeb || !Platform.isAndroid) {
      await _openInBrowser();
      return;
    }

    setState(() {
      _stage = _UpdateDialogStage.downloading;
      _progress = 0;
      _receivedBytes = 0;
      _totalBytes = widget.update.apkSize;
      _cancelled = false;
      _errorMessage = null;
    });

    try {
      final path = await AppUpdateService.downloadApk(
        widget.update,
        isCancelled: () => _cancelled,
        onProgress: (progress, received, total) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _receivedBytes = received;
            _totalBytes = total;
          });
        },
      );

      if (!mounted) return;
      _downloadedApkPath = path;
      await _tryLaunchInstaller();
    } catch (e) {
      if (!mounted) return;
      if (_cancelled) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _stage = _UpdateDialogStage.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _tryLaunchInstaller() async {
    final path = _downloadedApkPath;
    if (path == null) return;

    final canInstall = await AppUpdateService.canRequestPackageInstalls();
    if (!mounted) return;

    if (!canInstall) {
      setState(() => _stage = _UpdateDialogStage.needsPermission);
      return;
    }

    setState(() => _stage = _UpdateDialogStage.readyToInstall);
    try {
      await AppUpdateService.installApk(path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _UpdateDialogStage.error;
        _errorMessage = 'تعذر فتح مثبت النظام تلقائياً. يمكنك التثبيت عبر المتصفح.';
      });
    }
  }

  Future<void> _openInBrowser() async {
    try {
      await AppUpdateService.openReleaseInBrowser(widget.update.downloadUrl);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stage = _UpdateDialogStage.error;
        _errorMessage = 'تعذر فتح رابط التحميل في المتصفح.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizeLabel = widget.update.apkSize > 0
        ? ' (${_formatBytes(widget.update.apkSize)})'
        : '';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryNavy.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: AppTheme.primaryNavy,
              size: 26,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'يتوفر تحديث جديد للتطبيق',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryNavy,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.royalGold.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الحالي: ${AppVersion.displayVersion}',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.primaryNavy),
                  Text(
                    'الجديد: v${widget.update.version}$sizeLabel',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ],
              ),
            ),
            if (_stage == _UpdateDialogStage.prompt &&
                widget.update.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'تفاصيل التحديث:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  widget.update.releaseNotes,
                  style: const TextStyle(fontSize: 12.5, height: 1.45),
                ),
              ),
            ],
            if (_stage == _UpdateDialogStage.downloading) ...[
              const SizedBox(height: 16),
              const Text(
                'جارٍ تنزيل التحديث بشكل آمن من GitHub...',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  color: AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _totalBytes > 0
                        ? '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}'
                        : _formatBytes(_receivedBytes),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  Text(
                    _progress != null ? '${(_progress! * 100).toStringAsFixed(0)}%' : '...',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ],
              ),
            ],
            if (_stage == _UpdateDialogStage.needsPermission) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                ),
                child: const Text(
                  'تم تنزيل التحديث بنجاح.\nللتثبيت المباشر، يرجى تفعيل خيار "السماح بتثبيت التطبيقات من هذا المصدر" لهذا التطبيق في إعدادات الهاتف ثم العودة والضغط على "متابعة التثبيت".',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ],
            if (_stage == _UpdateDialogStage.readyToInstall) ...[
              const SizedBox(height: 14),
              const Text(
                'تم تنزيل التحديث بنجاح وجاهز للتثبيت. إذا لم تفتح نافذة التثبيت تلقائياً، اضغط على "تثبيت التحديث الآن".',
                style: TextStyle(fontSize: 13, height: 1.45),
              ),
            ],
            if (_stage == _UpdateDialogStage.error && _errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(fontSize: 12.5, color: Colors.red.shade900),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: _buildActions(),
    );
  }

  List<Widget> _buildActions() {
    switch (_stage) {
      case _UpdateDialogStage.prompt:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('لاحقاً', style: TextStyle(color: Colors.grey)),
          ),
          if (!kIsWeb && Platform.isAndroid)
            TextButton(
              onPressed: _openInBrowser,
              child: const Text('عبر المتصفح'),
            ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: AppTheme.royalGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _startDownloadAndInstall,
            icon: const Icon(Icons.download_rounded, size: 19),
            label: const Text('تحديث الآن', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ];

      case _UpdateDialogStage.downloading:
        return [
          TextButton(
            onPressed: () {
              setState(() => _cancelled = true);
            },
            child: const Text('إلغاء التنزيل', style: TextStyle(color: Colors.red)),
          ),
        ];

      case _UpdateDialogStage.needsPermission:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('لاحقاً', style: TextStyle(color: Colors.grey)),
          ),
          const OutlinedButton(
            onPressed: AppUpdateService.openUnknownAppSourcesSettings,
            child: Text('فتح الإعدادات'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: AppTheme.royalGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _tryLaunchInstaller,
            child: const Text('متابعة التثبيت', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ];

      case _UpdateDialogStage.readyToInstall:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: AppTheme.royalGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _tryLaunchInstaller,
            icon: const Icon(Icons.install_mobile_rounded, size: 19),
            label: const Text('تثبيت التحديث الآن', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ];

      case _UpdateDialogStage.error:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق', style: TextStyle(color: Colors.grey)),
          ),
          if (!kIsWeb && Platform.isAndroid)
            TextButton(
              onPressed: _openInBrowser,
              child: const Text('تحميل عبر المتصفح'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: AppTheme.royalGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _startDownloadAndInstall,
            child: const Text('إعادة المحاولة'),
          ),
        ];
    }
  }
}
