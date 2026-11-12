import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../components/app_logo.dart';
import '../core/app_events.dart';
import '../core/app_notification.dart';
import '../core/app_theme.dart';
import '../core/db_helper.dart';
import '../core/share_helper.dart';
import '../core/upholsterer_statement_helper.dart';

class UpholstererStatementScreen extends StatefulWidget {
  final String? initialCategoryFilter;
  final String? initialUpholstererFilter;
  final List<Map<String, dynamic>>? preloadedBatches;
  final List<Map<String, dynamic>>? preloadedTransactions;
  final List<Map<String, dynamic>>? preloadedCategories;

  const UpholstererStatementScreen({
    super.key,
    this.initialCategoryFilter,
    this.initialUpholstererFilter,
    this.preloadedBatches,
    this.preloadedTransactions,
    this.preloadedCategories,
  });

  @override
  State<UpholstererStatementScreen> createState() =>
      _UpholstererStatementScreenState();
}

enum _DatePreset { today, last7Days, thisMonth, lastMonth, all, custom }

class _UpholstererStatementScreenState
    extends State<UpholstererStatementScreen> {
  final GlobalKey _captureKey = GlobalKey();

  bool _isLoading = true;
  bool _isSharing = false;

  List<Map<String, dynamic>> _batches = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _categories = [];

  _DatePreset _activePreset = _DatePreset.thisMonth;
  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedCategory = 'all';
  String _selectedUpholsterer = 'all';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month, now.day);

    if (widget.initialCategoryFilter != null &&
        widget.initialCategoryFilter!.trim().isNotEmpty) {
      _selectedCategory = widget.initialCategoryFilter!.trim();
    }
    if (widget.initialUpholstererFilter != null &&
        widget.initialUpholstererFilter!.trim().isNotEmpty) {
      _selectedUpholsterer = widget.initialUpholstererFilter!.trim();
    }

    if (widget.preloadedBatches != null ||
        widget.preloadedTransactions != null ||
        widget.preloadedCategories != null) {
      _batches = widget.preloadedBatches ?? const [];
      _transactions = widget.preloadedTransactions ?? const [];
      _categories = widget.preloadedCategories ?? const [];
      _isLoading = false;
    } else {
      _loadData();
      AppEvents.instance.refreshNotifier.addListener(_loadData);
    }
  }

  @override
  void dispose() {
    if (widget.preloadedBatches == null &&
        widget.preloadedTransactions == null &&
        widget.preloadedCategories == null) {
      AppEvents.instance.refreshNotifier.removeListener(_loadData);
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final db = await DBHelper.instance.database;
    final batches = await db.query('upholsterer_batches', orderBy: 'id DESC');
    final categories = await db.query('categories', orderBy: 'name ASC');
    List<Map<String, dynamic>> txs = [];
    try {
      txs = await db.query('upholsterer_transactions', orderBy: 'id DESC');
    } catch (_) {}

    if (mounted) {
      setState(() {
        _batches = batches;
        _categories = categories;
        _transactions = txs;
        _isLoading = false;
      });
    }
  }

  void _applyPreset(_DatePreset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _activePreset = preset;
      switch (preset) {
        case _DatePreset.today:
          _fromDate = today;
          _toDate = today;
          break;
        case _DatePreset.last7Days:
          _fromDate = today.subtract(const Duration(days: 6));
          _toDate = today;
          break;
        case _DatePreset.thisMonth:
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate = today;
          break;
        case _DatePreset.lastMonth:
          final prevMonthEnd = DateTime(now.year, now.month, 0);
          _fromDate = DateTime(prevMonthEnd.year, prevMonthEnd.month, 1);
          _toDate = prevMonthEnd;
          break;
        case _DatePreset.all:
        case _DatePreset.custom:
          if (preset == _DatePreset.all) {
            _fromDate = null;
            _toDate = null;
          }
          break;
      }
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom
        ? (_fromDate ?? DateTime(now.year, now.month, 1))
        : (_toDate ?? DateTime(now.year, now.month, now.day));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ar', 'EG'),
      helpText: isFrom ? 'اختر تاريخ البداية (من)' : 'اختر تاريخ النهاية (إلى)',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _activePreset = _DatePreset.custom;
      final clean = DateTime(picked.year, picked.month, picked.day);
      if (isFrom) {
        _fromDate = clean;
        if (_toDate != null && _toDate!.isBefore(clean)) {
          _toDate = clean;
        }
      } else {
        _toDate = clean;
        if (_fromDate != null && _fromDate!.isAfter(clean)) {
          _fromDate = clean;
        }
      }
    });
  }

  String _periodDisplayLabel() {
    if (_fromDate == null && _toDate == null) {
      return 'جميع الفترات';
    }
    final fromStr = _fromDate != null
        ? UpholstererStatementHelper.formatIsoDate(_fromDate!)
        : 'البداية';
    final toStr = _toDate != null
        ? UpholstererStatementHelper.formatIsoDate(_toDate!)
        : 'الآن';
    return 'من $fromStr إلى $toStr';
  }

  Future<void> _shareAsImage(UpholstererStatementReport report) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final errorMsg = await ShareHelper.captureAndShareToWhatsApp(
        boundaryKey: _captureKey,
        fileNamePrefix: 'upholsterer_statement',
        captionText: 'كشف حساب المنجد - معرض الألفي',
      );

      if (mounted && errorMsg != null) {
        AppNotification.showInfo(context, errorMsg);
      }
    } catch (e) {
      if (mounted) {
        AppNotification.showError(context, 'تعذر تصدير صورة كشف الحساب: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  List<String> _collectAvailableCategories() {
    final Set<String> names = {};
    for (final c in _categories) {
      final n = (c['name'] ?? '').toString().trim();
      if (n.isNotEmpty) names.add(n);
    }
    for (final b in _batches) {
      final n = (b['category_name'] ?? '').toString().trim();
      if (n.isNotEmpty) names.add(n);
    }
    for (final t in _transactions) {
      final n = (t['category_name'] ?? '').toString().trim();
      if (n.isNotEmpty) names.add(n);
    }
    final list = names.toList()..sort();
    return list;
  }

  List<String> _collectAvailableUpholsterers() {
    final Set<String> names = {};
    for (final b in _batches) {
      final n = (b['upholsterer_name'] ?? '').toString().trim();
      if (n.isNotEmpty) names.add(n);
    }
    for (final t in _transactions) {
      final n = (t['upholsterer_name'] ?? '').toString().trim();
      if (n.isNotEmpty) names.add(n);
    }
    final list = names.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final availableCategories = _collectAvailableCategories();
    final availableUpholsterers = _collectAvailableUpholsterers();

    final String effectiveCat = (_selectedCategory != 'all' &&
            !availableCategories.contains(_selectedCategory))
        ? 'all'
        : _selectedCategory;
    final String effectiveUph = (_selectedUpholsterer != 'all' &&
            !availableUpholsterers.contains(_selectedUpholsterer))
        ? 'all'
        : _selectedUpholsterer;

    final report = UpholstererStatementHelper.buildStatement(
      batches: _batches,
      transactions: _transactions,
      categories: _categories,
      fromDate: _fromDate,
      toDate: _toDate,
      categoryNameFilter: effectiveCat,
      upholstererFilter: effectiveUph,
    );

    return Scaffold(
      backgroundColor: AppTheme.bgSurface,
      appBar: AppBar(
        title: const AppBarTitleWithLogo(title: 'كشف حساب المنجد'),
        actions: [
          IconButton(
            tooltip: 'مشاركة كشف الحساب على واتساب كصورة',
            onPressed: _isLoading || _isSharing ? null : () => _shareAsImage(report),
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_rounded, color: Color(0xFF128C7E)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFiltersBar(
                  availableCategories: availableCategories,
                  availableUpholsterers: availableUpholsterers,
                  effectiveCat: effectiveCat,
                  effectiveUph: effectiveUph,
                ),
                if (!report.hasAnyActivity && report.totalEventsBeforeDateFilter > 0)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade900, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'لا توجد حركات في الفترة المحددة، رغم وجود (${report.totalEventsBeforeDateFilter}) حركة في فترات أخرى.',
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _applyPreset(_DatePreset.all),
                          child: const Text('عرض الكل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    child: RepaintBoundary(
                      key: _captureKey,
                      child: _StatementReceiptCard(
                        report: report,
                        periodLabel: _periodDisplayLabel(),
                        categoryLabel: effectiveCat == 'all' ? 'جميع الأصناف' : effectiveCat,
                        upholstererLabel: effectiveUph == 'all' ? 'جميع المنجدين' : effectiveUph,
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF128C7E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            onPressed: _isLoading || _isSharing ? null : () => _shareAsImage(report),
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.share_rounded, size: 22),
            label: Text(
              _isSharing ? 'جاري تجهيز صورة الكشف...' : 'مشاركة كشف الحساب على واتساب (صورة)',
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersBar({
    required List<String> availableCategories,
    required List<String> availableUpholsterers,
    required String effectiveCat,
    required String effectiveUph,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
          // شرائح اختيار سريع للفترة
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip('اليوم', _DatePreset.today),
                const SizedBox(width: 6),
                _buildPresetChip('آخر 7 أيام', _DatePreset.last7Days),
                const SizedBox(width: 6),
                _buildPresetChip('هذا الشهر', _DatePreset.thisMonth),
                const SizedBox(width: 6),
                _buildPresetChip('الشهر الماضي', _DatePreset.lastMonth),
                const SizedBox(width: 6),
                _buildPresetChip('الكل', _DatePreset.all),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // فلتر التاريخ: من - إلى
          Row(
            children: [
              Expanded(
                child: _DateFieldButton(
                  label: 'من تاريخ',
                  dateText: _fromDate != null
                      ? UpholstererStatementHelper.formatIsoDate(_fromDate!)
                      : 'البداية',
                  onTap: () => _pickDate(isFrom: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateFieldButton(
                  label: 'إلى تاريخ',
                  dateText: _toDate != null
                      ? UpholstererStatementHelper.formatIsoDate(_toDate!)
                      : 'الآن',
                  onTap: () => _pickDate(isFrom: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // فلتر الأصناف والمنجد
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('cat_$effectiveCat'),
                  initialValue: effectiveCat,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'الصنف / الطقم',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: 'all',
                      child: Text('جميع الأصناف', overflow: TextOverflow.ellipsis),
                    ),
                    ...availableCategories.map((cat) => DropdownMenuItem<String>(
                          value: cat,
                          child: Text(cat, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('uph_$effectiveUph'),
                  initialValue: effectiveUph,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'المنجد',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: 'all',
                      child: Text('جميع المنجدين', overflow: TextOverflow.ellipsis),
                    ),
                    ...availableUpholsterers.map((u) => DropdownMenuItem<String>(
                          value: u,
                          child: Text(u, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedUpholsterer = val);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, _DatePreset preset) {
    final selected = _activePreset == preset;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _applyPreset(preset),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryNavy : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryNavy : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? AppTheme.royalGold : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _DateFieldButton extends StatelessWidget {
  final String label;
  final String dateText;
  final VoidCallback onTap;

  const _DateFieldButton({
    required this.label,
    required this.dateText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.primaryNavy),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة كشف الحساب الرسمية القابلة للتصوير والمشاركة كصورة على واتساب
class _StatementReceiptCard extends StatelessWidget {
  final UpholstererStatementReport report;
  final String periodLabel;
  final String categoryLabel;
  final String upholstererLabel;

  const _StatementReceiptCard({
    required this.report,
    required this.periodLabel,
    required this.categoryLabel,
    required this.upholstererLabel,
  });

  @override
  Widget build(BuildContext context) {
    final issuedAt =
        intl.DateFormat('yyyy-MM-dd hh:mm a').format(DateTime.now());
    final sent = report.deliveredToUpholsterer;
    final rec = report.receivedFromUpholsterer;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryNavy.withValues(alpha: 0.18), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. الترويسة الرسمية للكشف
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryNavy, Color(0xFF28507D)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Row(
              children: [
                const AppLogo(size: 46),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'كشف حساب ورشة المنجد',
                        style: TextStyle(
                          color: AppTheme.royalGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 16.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ملخص التسليم والاستلام • نظام الألفي',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.royalGold.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    UpholstererStatementHelper.formatIsoDate(DateTime.now()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. شريط معايير الفلتر النشط
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFFF1F5F9),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _MetaBadge(
                  icon: Icons.date_range_rounded,
                  label: 'الفترة:',
                  value: periodLabel,
                ),
                _MetaBadge(
                  icon: Icons.weekend_rounded,
                  label: 'الصنف:',
                  value: categoryLabel,
                ),
                if (upholstererLabel != 'جميع المنجدين')
                  _MetaBadge(
                    icon: Icons.person_rounded,
                    label: 'المنجد:',
                    value: upholstererLabel,
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 3. بطاقات الملخص الإجمالي (كم طقم وكم فردي للتسليم والاستلام)
                Row(
                  children: [
                    Expanded(
                      child: _SummaryKpiBox(
                        title: 'إجمالي التسليم للمنجد',
                        sets: sent.totalSets,
                        individualPieces: sent.totalIndividualPieces,
                        totalPieces: sent.totalPieces,
                        operationsCount: sent.operationsCount,
                        icon: Icons.outbox_rounded,
                        accentColor: const Color(0xFF1E3A8A),
                        bgColor: const Color(0xFFEFF6FF),
                        borderColor: const Color(0xFFBFDBFE),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryKpiBox(
                        title: 'إجمالي الاستلام من المنجد',
                        sets: rec.totalSets,
                        individualPieces: rec.totalIndividualPieces,
                        totalPieces: rec.totalPieces,
                        operationsCount: rec.operationsCount,
                        icon: Icons.move_to_inbox_rounded,
                        accentColor: const Color(0xFF15803D),
                        bgColor: const Color(0xFFF0FDF4),
                        borderColor: const Color(0xFFBBF7D0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. أولاً: التسليم للمنجد (مجمّع مع بعضه)
                _StatementGroupSection(
                  title: 'أولاً: التسليم للمنجد',
                  emptyMessage: 'لا توجد حركات تسليم للمنجد خلال هذه الفترة.',
                  icon: Icons.outbox_rounded,
                  accentColor: const Color(0xFF1E3A8A),
                  headerBgColor: const Color(0xFFEFF6FF),
                  borderColor: const Color(0xFFBFDBFE),
                  section: sent,
                ),
                const SizedBox(height: 16),

                // 5. ثانياً: الاستلام من المنجد (مجمّع مع بعضه)
                _StatementGroupSection(
                  title: 'ثانياً: الاستلام من المنجد',
                  emptyMessage: 'لا توجد حركات استلام من المنجد خلال هذه الفترة.',
                  icon: Icons.move_to_inbox_rounded,
                  accentColor: const Color(0xFF15803D),
                  headerBgColor: const Color(0xFFF0FDF4),
                  borderColor: const Color(0xFFBBF7D0),
                  section: rec,
                ),
                const SizedBox(height: 14),

                // 6. تذييل الكشف
                Divider(color: Colors.grey.shade200, height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'معرض الألفي • كشف حساب المنجد',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      issuedAt,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaBadge({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.5, color: AppTheme.primaryNavy),
          const SizedBox(width: 4),
          Text(
            '$label ',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryNavy, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _SummaryKpiBox extends StatelessWidget {
  final String title;
  final int sets;
  final int individualPieces;
  final int totalPieces;
  final int operationsCount;
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;

  const _SummaryKpiBox({
    required this.title,
    required this.sets,
    required this.individualPieces,
    required this.totalPieces,
    required this.operationsCount,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: accentColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CountMetric(
                  value: sets,
                  unit: 'طقم',
                  accentColor: accentColor,
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: borderColor,
              ),
              Expanded(
                child: _CountMetric(
                  value: individualPieces,
                  unit: 'فردي',
                  accentColor: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'القطع: $totalPieces قطعة • الحركات: $operationsCount',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountMetric extends StatelessWidget {
  final int value;
  final String unit;
  final Color accentColor;

  const _CountMetric({
    required this.value,
    required this.unit,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: accentColor,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          unit,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

class _StatementGroupSection extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final IconData icon;
  final Color accentColor;
  final Color headerBgColor;
  final Color borderColor;
  final UpholstererStatementSection section;

  const _StatementGroupSection({
    required this.title,
    required this.emptyMessage,
    required this.icon,
    required this.accentColor,
    required this.headerBgColor,
    required this.borderColor,
    required this.section,
  });

  static const int _maxVisibleOperationsInCard = 25;

  @override
  Widget build(BuildContext context) {
    final summaryText = UpholstererStatementHelper.formatSetsAndIndividual(
      section.totalSets,
      section.totalIndividualPieces,
    );

    final visibleOps = section.operations.take(_maxVisibleOperationsInCard).toList();
    final hiddenOpsCount = section.operations.length - visibleOps.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ترويسة القسم
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: headerBgColor,
            child: Row(
              children: [
                Icon(icon, size: 19, color: accentColor),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    section.isEmpty ? '0' : summaryText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (section.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ملخص الأصناف داخل القسم
                  Text(
                    'ملخص الأصناف (${section.categorySummaries.length}):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...section.categorySummaries.map((cat) {
                    final catLabel = UpholstererStatementHelper.formatSetsAndIndividual(
                      cat.sets,
                      cat.individualPieces,
                    );
                    final piecesLine = cat.pieceTotals.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join(' • ');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blueGrey.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'طقم: ${cat.categoryName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: AppTheme.primaryNavy,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: headerBgColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Text(
                                  '$catLabel (${cat.totalPieces} قطعة)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (piecesLine.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              piecesLine,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                  // سجل الحركات التفصيلي بالتواريخ
                  const SizedBox(height: 6),
                  Text(
                    'سجل الحركات (${section.operations.length}):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...visibleOps.map((op) {
                    final opSummary = UpholstererStatementHelper.formatSetsAndIndividual(
                      op.sets,
                      op.individualPieces,
                    );
                    final opPiecesText = op.pieces
                        .map((p) => '${p['name']} (${p['qty']})')
                        .join('، ');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              op.actionDate.isNotEmpty ? op.actionDate : '-',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${op.categoryName}${op.upholstererName.isNotEmpty ? ' • ${op.upholstererName}' : ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppTheme.primaryNavy,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      opSummary,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                                if (opPiecesText.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    opPiecesText,
                                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (hiddenOpsCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+ $hiddenOpsCount عمليات أقدم ضمن نفس الفترة (محتسبة بالكامل في الإجماليات أعلاه)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
