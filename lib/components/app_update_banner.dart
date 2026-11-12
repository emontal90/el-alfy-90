import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_update_service.dart';
import 'app_update_dialog.dart';

class AppUpdateBanner {
  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  /// إظهار إشعار عائم أنيق وجانبي لبضع ثوانٍ يفيد بوجود تحديث جديد
  static void show(BuildContext context, AppUpdateInfo update) {
    dismiss();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (ctx) => _AppUpdateBannerWidget(
        update: update,
        onDismiss: dismiss,
        onUpdateNow: () {
          dismiss();
          AppUpdateDialog.show(context, update);
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);

    // إخفاء تلقائي بعد 8 ثوانٍ دون إزعاج المستخدم إذا لم يتفاعل مع الإشعار
    _dismissTimer = Timer(const Duration(seconds: 8), () {
      dismiss();
    });
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _activeEntry?.remove();
    _activeEntry = null;
  }
}

class _AppUpdateBannerWidget extends StatefulWidget {
  final AppUpdateInfo update;
  final VoidCallback onDismiss;
  final VoidCallback onUpdateNow;

  const _AppUpdateBannerWidget({
    required this.update,
    required this.onDismiss,
    required this.onUpdateNow,
  });

  @override
  State<_AppUpdateBannerWidget> createState() => _AppUpdateBannerWidgetState();
}

class _AppUpdateBannerWidgetState extends State<_AppUpdateBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _offsetAnim = Tween<Offset>(
      begin: const Offset(0.0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top + 10;

    return Positioned(
      top: topPadding,
      left: 14,
      right: 14,
      child: Material(
        type: MaterialType.transparency,
        child: SlideTransition(
          position: _offsetAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryNavy, Color(0xFF28507D)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.royalGold, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // أيقونة التحديث مع مؤشر حدث باللون الأحمر/الذهبي
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.system_update_rounded,
                          color: AppTheme.royalGold,
                          size: 24,
                        ),
                      ),
                      Positioned(
                        top: -3,
                        left: -3,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Text(
                            '1',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // نص التحديث
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'يتوفر تحديث جديد',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.royalGold,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.update.tagName,
                                style: const TextStyle(
                                  color: AppTheme.primaryNavy,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'اضغط للتحديث الآن أو الإعداد لاحقاً من الترس',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // زرا التحديث ولاحقاً
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.royalGold,
                          foregroundColor: AppTheme.primaryNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: widget.onUpdateNow,
                        child: const Text(
                          'تحديث',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: _handleDismiss,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'لاحقاً',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
