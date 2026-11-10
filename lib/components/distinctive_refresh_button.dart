import 'package:flutter/material.dart';
import '../core/app_events.dart';
import '../core/app_notification.dart';

/// زر ريفرش صغير ومميز في الهيدر بلون برتقالي داكن متباين وخط داكن واضح
class DistinctiveRefreshButton extends StatefulWidget {
  const DistinctiveRefreshButton({super.key});

  @override
  State<DistinctiveRefreshButton> createState() => _DistinctiveRefreshButtonState();
}

class _DistinctiveRefreshButtonState extends State<DistinctiveRefreshButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleRefresh() {
    _controller.forward(from: 0.0);
    AppEvents.instance.notifyAll();
    AppNotification.showSuccess(context, 'تم تحديث كافة البيانات بنجاح');
  }

  @override
  Widget build(BuildContext context) {
    // لون برتقالي غني وداكن مع خط وأيقونة كحلية داكنة جداً لتحقيق أعلى درجات التباين والوضوح
    const Color orangeBg = Color(0xFFFF9800); // برتقالي قوي وواضح
    const Color darkNavyText = Color(0xFF0F2038); // كحلي داكن جداً ومتباين

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: orangeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE65100), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Tooltip(
        message: 'تحديث فوري لجميع القوائم',
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _handleRefresh,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RotationTransition(
                  turns: _controller,
                  child: const Icon(Icons.refresh_rounded, color: darkNavyText, size: 20),
                ),
                const SizedBox(width: 6),
                const Text(
                  'تحديث',
                  style: TextStyle(
                    color: darkNavyText,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
