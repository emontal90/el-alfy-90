import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.22), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.06),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10.0 : 13.0,
            vertical: isCompact ? 10.0 : 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // الصف العلوي: أيقونة القائمة + شارة اسم القائمة المميز بدلاً من "تقرير حي"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(isCompact ? 5.5 : 7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: isCompact ? 18 : 22),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.25)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              style: TextStyle(
                                color: color,
                                fontSize: isCompact ? 10.5 : 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.arrow_forward_ios_rounded, size: 9, color: color),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // القيمة والبيان الرئيسي للرقم
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: isCompact ? 16.5 : 18,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              ),

              // مؤشر تفاعلي للتنقل السريع
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'اضغط لفتح القائمة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.touch_app_rounded, size: 13, color: color.withValues(alpha: 0.8)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// كارت إحصائي مقسوم لنصفين (نصف للنمطي ونصف للأوردر)
class SplitStatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int standardCount; // نمطي
  final int customCount;   // أوردر
  final VoidCallback? onTap;

  const SplitStatCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.standardCount,
    required this.customCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = standardCount + customCount;
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.22), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.06),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 9.0 : 12.0,
            vertical: isCompact ? 9.0 : 10.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // الصف العلوي: الأيقونة + اسم القائمة المميز
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(isCompact ? 5 : 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: isCompact ? 17 : 20),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.25)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              style: TextStyle(
                                color: color,
                                fontSize: isCompact ? 10.5 : 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.arrow_forward_ios_rounded, size: 9, color: color),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // منتصف الكارت: مقسوم إلى نصفين (نصف للنمطي ونصف للأوردر)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    // النصف الأول: نمطي
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'نمطي',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '$standardCount',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // فاصل رأسي بين النصفين
                    Container(
                      width: 1,
                      height: 32,
                      color: color.withValues(alpha: 0.25),
                    ),
                    // النصف الثاني: أوردر
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'أوردر',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '$customCount',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // الصف السفلي: إجمالي الطلبات ومؤشر الضغط
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الإجمالي: $total',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'فتح القائمة',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.touch_app_rounded, size: 12, color: color.withValues(alpha: 0.8)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
