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
    final compStr = comps.map((c) => 'عدد ${c['qty']} ${c['name']}').join(' + ');

    final createdAtRaw = order['created_at']?.toString() ?? '';
    final createdAtFormatted = createdAtRaw.isNotEmpty
        ? StockMovementHelper.formatDateString12(createdAtRaw)
        : '';

    final int? setsCount = (order['sets_count'] as int?);
    final setsText = (setsCount != null && setsCount > 0) ? ' [عدد $setsCount طقم]' : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الزبون: ${order['customer_name']}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDelivered ? Colors.green.shade100 : Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'موعد التسليم: ${order['delivery_date']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              'اسم الطقم: ${order['category_name']} (${order['order_type']}) $setsText',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('المكونات: $compStr'),
            if (order['specs'] != null && order['specs'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('المواصفات: ${order['specs']}', style: const TextStyle(color: Colors.black54)),
            ],

            // تاريخ ووقت تسجيل الطلب بخط صغير
            if (createdAtFormatted.isNotEmpty) ...[
              const SizedBox(height: 6),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: onDeliverPressed,
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('تم التسليم', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}
