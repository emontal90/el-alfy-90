import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ShareHelper {
  static const MethodChannel _channel = MethodChannel('com.example.furniture_erp/share');

  /// التقاط الويدجت المربوط بـ [boundaryKey] كصورة PNG عالية الدقة ومشاركتها على واتساب
  static Future<String?> captureAndShareToWhatsApp({
    required GlobalKey boundaryKey,
    required String fileNamePrefix,
    String? captionText,
  }) async {
    if (kIsWeb) {
      return 'مشاركة الصور غير مدعومة على نسخة المتصفح.';
    }

    await WidgetsBinding.instance.endOfFrame;

    final RenderObject? renderObj = boundaryKey.currentContext?.findRenderObject();
    if (renderObj is! RenderRepaintBoundary) {
      return 'تعذر تجهيز صورة كشف الحساب، يرجى المحاولة مرة أخرى.';
    }

    final Size widgetSize = renderObj.size;
    final double maxDim = widgetSize.width > widgetSize.height ? widgetSize.width : widgetSize.height;
    final double pixelRatio = maxDim > 3200
        ? 1.5
        : (maxDim > 2000 ? 2.0 : 2.5);

    final ui.Image image = await renderObj.toImage(pixelRatio: pixelRatio);
    try {
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return 'فشل تحويل كشف الحساب إلى صورة.';
      }
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final Directory tempDir = await getTemporaryDirectory();
      final Directory shareDir = Directory(p.join(tempDir.path, 'shared_statements'));
      if (!await shareDir.exists()) {
        await shareDir.create(recursive: true);
      }

      final String safePrefix = fileNamePrefix.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final String filePath = p.join(
        shareDir.path,
        '${safePrefix}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      final File file = File(filePath);
      await file.writeAsBytes(pngBytes, flush: true);

      try {
        await _channel.invokeMethod('shareImageToWhatsApp', {
          'path': file.path,
          'text': captionText ?? '',
        });
        return null;
      } on MissingPluginException {
        return 'تم حفظ صورة الكشف في: ${file.path}\n(المشاركة المباشرة لواتساب متاحة على تطبيق الأندرويد)';
      } on PlatformException catch (e) {
        return e.message ?? 'تعذر فتح تطبيق واتساب للمشاركة.';
      }
    } finally {
      image.dispose();
    }
  }
}

