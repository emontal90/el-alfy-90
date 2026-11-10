import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../components/app_logo.dart';
import '../components/distinctive_refresh_button.dart';
import '../components/order_card.dart';
import '../core/app_events.dart';
import '../core/app_theme.dart';
import '../core/db_helper.dart';

class DeliveredOrdersScreen extends StatefulWidget {
  const DeliveredOrdersScreen({super.key});
  @override
  State<DeliveredOrdersScreen> createState() => _DeliveredOrdersScreenState();
}

class _DeliveredOrdersScreenState extends State<DeliveredOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // فلاتر تاريخ التسليم: الكل، اليوم، أو فترة مخصصة (من - إلى)
  String _dateFilterType = 'all'; // 'all', 'today', 'range'
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _load();
    AppEvents.instance.refreshNotifier.addListener(_load);
  }

  @override
  void dispose() {
    AppEvents.instance.refreshNotifier.removeListener(_load);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = await DBHelper.instance.database;
    final data = await db.query('orders', where: "status = 'delivered'", orderBy: 'id DESC');
    if (mounted) setState(() => _orders = data);
  }

  /// تصفية الأوردرات المسلّمة حسب فترة التاريخ والبحث
  List<Map<String, dynamic>> get _filteredOrders {
    final now = DateTime.now();
    final todayStr = intl.DateFormat('yyyy-MM-dd').format(now);

    return _orders.where((o) {
      final custName = (o['customer_name'] ?? '').toString().toLowerCase();
      final catName = (o['category_name'] ?? '').toString().toLowerCase();
      final deliveryDateStr = (o['delivery_date'] ?? '').toString().trim();

      // فلتر البحث بالاسم أو الصنف
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        if (!custName.contains(q) && !catName.contains(q)) {
          return false;
        }
      }

      // فلتر تاريخ التسليم
      if (_dateFilterType == 'today') {
        if (deliveryDateStr != todayStr) return false;
      } else if (_dateFilterType == 'range') {
        if (_startDate != null || _endDate != null) {
          DateTime? dDate = DateTime.tryParse(deliveryDateStr);
          if (dDate != null) {
            final dOnly = DateTime(dDate.year, dDate.month, dDate.day);
            if (_startDate != null) {
              final sOnly = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
              if (dOnly.isBefore(sOnly)) return false;
            }
            if (_endDate != null) {
              final eOnly = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
              if (dOnly.isAfter(eOnly)) return false;
            }
          } else {
            final dStr = deliveryDateStr.length >= 10 ? deliveryDateStr.substring(0, 10) : deliveryDateStr;
            if (_startDate != null) {
              final sStr = intl.DateFormat('yyyy-MM-dd').format(_startDate!);
              if (dStr.compareTo(sStr) < 0) return false;
            }
            if (_endDate != null) {
              final eStr = intl.DateFormat('yyyy-MM-dd').format(_endDate!);
              if (dStr.compareTo(eStr) > 0) return false;
            }
          }
        }
      }

      return true;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange = (_startDate != null && _endDate != null)
        ? DateTimeRange(start: _startDate!, end: _endDate!)
        : DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: initialRange,
      helpText: 'اختر فترة التسليم (من - إلى)',
      cancelText: 'إلغاء',
      confirmText: 'تطبيق الفلتر',
      saveText: 'تطبيق',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryNavy,
              onPrimary: AppTheme.royalGold,
              surface: Colors.white,
              onSurface: AppTheme.primaryNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _dateFilterType = 'range';
      });
    }
  }

  Future<void> _pickSingleStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'اختر تاريخ البداية (من)',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _dateFilterType = 'range';
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickSingleEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'اختر تاريخ النهاية (إلى)',
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _dateFilterType = 'range';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredOrders;
    final bool hasActiveFilter = _dateFilterType != 'all' || _searchQuery.trim().isNotEmpty;

    String rangeLabel = 'فترة محددة (من - إلى) 📅';
    if (_startDate != null && _endDate != null) {
      rangeLabel = 'من: ${intl.DateFormat('yyyy-MM-dd').format(_startDate!)}  إلى: ${intl.DateFormat('yyyy-MM-dd').format(_endDate!)}';
    } else if (_startDate != null) {
      rangeLabel = 'من: ${intl.DateFormat('yyyy-MM-dd').format(_startDate!)}';
    } else if (_endDate != null) {
      rangeLabel = 'حتى: ${intl.DateFormat('yyyy-MM-dd').format(_endDate!)}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            AppLogo(size: 34),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'سجل الأوردرات التي تم تسليمها',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: const [
          DistinctiveRefreshButton(),
        ],
      ),
      body: Column(
        children: [
          // شريط فلترة تاريخ التسليم والبحث
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // حقل البحث
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'بحث باسم العميل أو اسم الطقم المسلّم...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchCtrl.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 8),

                // أزرار فلاتر تاريخ التسليم: الكل، اليوم، والفترة (من - إلى)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _DateFilterChip(
                        label: 'الكل (${_orders.length})',
                        icon: Icons.list_alt,
                        isSelected: _dateFilterType == 'all',
                        onTap: () {
                          setState(() {
                            _dateFilterType = 'all';
                            _startDate = null;
                            _endDate = null;
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      _DateFilterChip(
                        label: 'تسليم اليوم',
                        icon: Icons.today,
                        isSelected: _dateFilterType == 'today',
                        onTap: () {
                          setState(() {
                            _dateFilterType = 'today';
                            _startDate = null;
                            _endDate = null;
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      _DateFilterChip(
                        label: rangeLabel,
                        icon: Icons.date_range_rounded,
                        isSelected: _dateFilterType == 'range',
                        onTap: _pickDateRange,
                      ),
                      if (hasActiveFilter) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          ),
                          onPressed: () {
                            setState(() {
                              _searchCtrl.clear();
                              _searchQuery = '';
                              _dateFilterType = 'all';
                              _startDate = null;
                              _endDate = null;
                            });
                          },
                          icon: const Icon(Icons.filter_alt_off, size: 16),
                          label: const Text('مسح الفلتر', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ),

                // شريط أزرار تحديد تاريخ "من" و "إلى" إذا كان فلتر الفترة نشطاً
                if (_dateFilterType == 'range') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryNavy.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickSingleStartDate,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today, size: 14, color: AppTheme.primaryNavy),
                                  const SizedBox(width: 6),
                                  Text(
                                    _startDate != null
                                        ? 'من: ${intl.DateFormat('yyyy-MM-dd').format(_startDate!)}'
                                        : 'من: حدد تاريخ',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(width: 1, height: 20, color: Colors.grey.shade300),
                        Expanded(
                          child: InkWell(
                            onTap: _pickSingleEndDate,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.event_available, size: 14, color: AppTheme.primaryNavy),
                                  const SizedBox(width: 6),
                                  Text(
                                    _endDate != null
                                        ? 'إلى: ${intl.DateFormat('yyyy-MM-dd').format(_endDate!)}'
                                        : 'إلى: حدد تاريخ',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'تغيير نطاق الفترة',
                          icon: const Icon(Icons.edit_calendar, size: 18, color: AppTheme.primaryNavy),
                          onPressed: _pickDateRange,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // قائمة الأوردرات المسلّمة
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hasActiveFilter ? Icons.search_off : Icons.inventory_2_outlined,
                            size: 50,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            hasActiveFilter
                                ? 'لا توجد أوردرات مسلّمة مطابقة للتاريخ والبحث المحددين.'
                                : 'لم يتم تسليم أي أوردر بعد.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) => OrderCard(
                      order: list[i],
                      isDelivered: true,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateFilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryNavy : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primaryNavy : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppTheme.royalGold : Colors.black87,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.royalGold : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
