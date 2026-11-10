import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/stock_movement_helper.dart';

class OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onDeliverPressed;
  final VoidCallback? onEditPressed;
  final bool isDelivered;

  const OrderCard({
    super.key,
    required this.order,
    this.onDeliverPressed,
    this.onEditPressed,
    this.isDelivered = false,
  });

  @override
  Widget build(BuildContext context) {
    List comps = [];
    try {
      comps = jsonDecode(order['selected_components_json']);
    } catch (_) {}

    final createdAtRaw = order['created_at']?.toString() ?? '';
    final createdAtFormatted = createdAtRaw.isNotEmpty
        ? StockMovementHelper.formatDateString12(createdAtRaw)
        : '';

    final int? setsCount = (order['sets_count'] as int?);
    final String deliveryDateStr = order['delivery_date']?.toString() ?? 'غير محدد';

    return Card(
      elevation: 2.5,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDelivered ? Colors.green.shade200 : AppTheme.royalGold.withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // الصف الأول: اسم العميل وموعد التسليم بتصميم مميز وبارز
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryNavy.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_pin_rounded, color: AppTheme.primaryNavy, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'العميل:',
                              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${order['customer_name']}',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // موعد التسليم المميز البارز
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDelivered
                          ? [const Color(0xFF15803D), const Color(0xFF166534)]
                          : [const Color(0xFFD97706), const Color(0xFFB45309)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (isDelivered ? Colors.green : Colors.amber.shade900).withOpacity(0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDelivered ? Icons.task_alt_rounded : Icons.alarm_on_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isDelivered ? 'تم التسليم' : 'موعد التسليم:',
                            style: const TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            deliveryDateStr,
                            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // الصف الثاني: اسم الطقم ونوعه وعدد الأطقم
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryNavy.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryNavy.withOpacity(0.12)),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  const Icon(Icons.weekend_rounded, size: 18, color: AppTheme.primaryNavy),
                  Text(
                    'طقم: ${order['category_name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryNavy),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${order['order_type']}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (setsCount != null && setsCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'عدد $setsCount طقم',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // الصف الثالث: عرض مكونات وقطع الطلب موحدة تماماً كشاشة المخزن
            const Text(
              'قطع ومكونات الطلب:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            if (comps.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: comps.map((c) {
                  final String pieceName = (c['name'] ?? '').toString();
                  final int pieceCount = (c['qty'] is int)
                      ? c['qty'] as int
                      : (int.tryParse(c['qty']?.toString() ?? '0') ?? 0);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: pieceCount > 0 ? Colors.blue.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: pieceCount > 0 ? Colors.blue.shade200 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chair_rounded,
                          size: 15,
                          color: pieceCount > 0 ? AppTheme.primaryNavy : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          pieceName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: pieceCount > 0 ? AppTheme.primaryNavy : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: pieceCount > 0 ? AppTheme.primaryNavy : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$pieceCount',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              )
            else
              Text(
                'طقم ${order['category_name']} كامل بجميع قطعه',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),

            // المواصفات إن وجدت
            if (order['specs'] != null && order['specs'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_rounded, size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'المواصفات: ${order['specs']}',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // تاريخ ووقت تسجيل الطلب بخط صغير
            if (createdAtFormatted.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'تاريخ تسجيل الطلب: $createdAtFormatted',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],

            // أزرار العمليات (تعديل الطلب / تم التسليم) مع الإبقاء عليها كما هي
            if (!isDelivered && (onEditPressed != null || onDeliverPressed != null)) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEditPressed != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryNavy,
                        foregroundColor: AppTheme.royalGold,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: onEditPressed,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('تعديل الطلب', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  if (onEditPressed != null && onDeliverPressed != null)
                    const SizedBox(width: 8),
                  if (onDeliverPressed != null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: onDeliverPressed,
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('تم التسليم', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
