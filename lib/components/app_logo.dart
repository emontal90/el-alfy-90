import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showBorder;

  const AppLogo({
    super.key,
    this.size = 80,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFBF9F4),
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: size * 0.1,
            offset: Offset(0, size * 0.04),
          ),
        ],
        border: showBorder
            ? Border.all(color: AppTheme.royalGold, width: size > 50 ? 2.0 : 1.2)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22 - (showBorder ? 1.5 : 0)),
        child: Image.asset(
          'assets/images/app_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.chair_rounded,
            size: size * 0.6,
            color: AppTheme.primaryNavy,
          ),
        ),
      ),
    );
  }
}

/// عنوان موحد ومتجاوب في الهيدر يعرض الشعار واسم الصفحة كاملاً (ورقم الإصدار اختيارياً) بدون قص على أي هاتف
class AppBarTitleWithLogo extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double logoSize;

  const AppBarTitleWithLogo({
    super.key,
    required this.title,
    this.subtitle,
    this.logoSize = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppLogo(size: logoSize),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.primaryNavy,
                  ),
                  maxLines: 1,
                ),
              ),
              if (subtitle != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryNavy.withValues(alpha: 0.68),
                    ),
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

