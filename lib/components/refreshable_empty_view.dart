import 'package:flutter/material.dart';

/// عرض موحد للحالات الفارغة يدعم السحب للأسفل لتحديث الصفحة (Pull-to-Refresh)
class RefreshableEmptyView extends StatelessWidget {
  final Widget child;

  const RefreshableEmptyView({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
