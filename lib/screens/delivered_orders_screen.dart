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

  // فلاتر تاريخ التسليم
  String _dateFilterType = 'all'; // 'all', 'today', 'this_week', 'this_month', 'custom'
  DateTime? _customSelectedDate;

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

  /// تصفية الأوردرات المسلّمة حسب تاريخ التسليم والبحث
  List<Map<String, dynamic>> get _filteredOrders {
    final now = DateTime.now();
    final todayStr = intl.DateFormat('yyyy-MM-dd').format(now);

    return _orders.where((o) {
      final custName = (o['customer_name'] ?? '').toString().toLowerCase();
      final catName = (o['category_name'] ?? '').toString().toLowerCase();
      final deliveryDateStr = (o['delivery_date'] ?? '').toString();

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
      } else if (_dateFilterType == 'this_week') {
        try {
          final delivDate = DateTime.parse(deliveryDateStr);
          final diffDays = now.difference(delivDate).inDays;
          if (diffDays < 0 || diffDays > 7) return false;
        } catch (_) {
          return false;
        }
      } else if (_dateFilterType == 'this_month') {
        final thisMonthPrefix = intl.DateFormat('yyyy-MM').format(now);
        if (!deliveryDateStr.startsWith(thisMonthPrefix)) return false;
      } else if (_dateFilterType == 'custom' && _customSelectedDate != null) {
        final customStr = intl.DateFormat('yyyy-MM-dd').format(_customSelectedDate!);
        if (deliveryDateStr != customStr) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customSelectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _customSelectedDate = picked;
        _dateFilterType = 'custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredOrders;
    final bool hasActiveFilter = _dateFilterType != 'all' || _searchQuery.trim().isNotEmpty;

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

                // أزرار فلاتر تاريخ التسليم
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _DateFilterChip(
                        label: 'الكل (${_orders.length})',
                        icon: Icons.list_alt,
                        isSelected: _dateFilterType == 'all',
                        onTap: () => setState(() => _dateFilterType = 'all'),
                      ),
                      const SizedBox(width: 6),
                      _DateFilterChip(
                        label: 'تسليم اليوم',
                        icon: Icons.today,
                        isSelected: _dateFilterType == 'today',
                        onTap: () => setState(() => _dateFilterType = 'today'),
                      ),
                      const SizedBox(width: 6),
                      _DateFilterChip(
                        label: 'آخر أسبوع',
                        icon: Icons.date_range,
                        isSelected: _dateFilterType == 'this_week',
                        onTap: () => setState(() => _dateFilterType = 'this_week'),
                      ),
                      const SizedBox(width: 6),
                      _DateFilterChip(
                        label: 'هذا الشهر',
                        icon: Icons.calendar_month,
                        isSelected: _dateFilterType == 'this_month',
                        onTap: () => setState(() => _dateFilterType = 'this_month'),
                      ),
                      const SizedBox(width: 6),
                      _DateFilterChip(
                        label: _customSelectedDate != null && _dateFilterType == 'custom'
                            ? intl.DateFormat('yyyy-MM-dd').format(_customSelectedDate!)
                            : 'تاريخ محدد 📅',
                        icon: Icons.event,
                        isSelected: _dateFilterType == 'custom',
                        onTap: _pickCustomDate,
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
                              _customSelectedDate = null;
                            });
                          },
                          icon: const Icon(Icons.filter_alt_off, size: 16),
                          label: const Text('مسح الفلتر', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ),
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
