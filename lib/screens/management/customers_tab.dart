import 'package:flutter/material.dart';
import '../../components/refreshable_empty_view.dart';
import '../../core/app_events.dart';
import '../../core/app_notification.dart';
import '../../core/app_theme.dart';
import '../../core/db_helper.dart';

class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key});
  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  List<Map<String, dynamic>> _customers = [];
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    AppEvents.instance.refreshNotifier.addListener(_load);
  }

  @override
  void dispose() {
    AppEvents.instance.refreshNotifier.removeListener(_load);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = await DBHelper.instance.database;
    final data = await db.query('customers', orderBy: 'id DESC');
    if (mounted) setState(() => _customers = data);
  }

  // رسالة تأكيد حذف عميل
  Future<void> _confirmDeleteCustomer(BuildContext context, Map<String, dynamic> c) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red, size: 30),
            SizedBox(width: 8),
            Text('تأكيد حذف العميل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف العميل "${c['name']}" من النظام؟',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = await DBHelper.instance.database;
      await db.delete('customers', where: 'id = ?', whereArgs: [c['id']]);
      AppEvents.instance.notifyAll();
      if (mounted) {
        AppNotification.showError(context, 'تم حذف العميل "${c['name']}" بنجاح');
      }
    }
  }

  void _openEditCustomerDialog(Map<String, dynamic> c) {
    _nameCtrl.text = (c['name'] ?? '').toString();
    _phoneCtrl.text = (c['phone'] ?? '').toString();
    _addressCtrl.text = (c['address'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: AppTheme.modalSheetPadding(ctx, horizontal: 20, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: AppTheme.primaryNavy, size: 26),
                    SizedBox(width: 8),
                    Text(
                      'تعديل بيانات العميل',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم العميل *',
                hintText: 'أدخل اسم العميل (إجباري)',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف (اختياري)',
                hintText: 'رقم التليفون أو المحمول',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'العنوان (اختياري)',
                hintText: 'عنوان العميل أو المنطقة',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: AppTheme.royalGold,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final name = _nameCtrl.text.trim();
                if (name.isEmpty) {
                  AppNotification.showError(ctx, 'يرجى إدخال اسم العميل أولاً');
                  return;
                }
                final phone = _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim();
                final address = _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim();

                final db = await DBHelper.instance.database;
                await db.update(
                  'customers',
                  {
                    'name': name,
                    'phone': phone,
                    'address': address,
                  },
                  where: 'id = ?',
                  whereArgs: [c['id']],
                );

                // تحديث اسم العميل في جدول الطلبات المرتبطة به
                await db.update(
                  'orders',
                  {'customer_name': name},
                  where: 'customer_id = ?',
                  whereArgs: [c['id']],
                );

                _nameCtrl.clear();
                _phoneCtrl.clear();
                _addressCtrl.clear();

                AppEvents.instance.notifyAll();
                if (mounted) {
                  Navigator.pop(ctx);
                  AppNotification.showSuccess(context, 'تم تعديل بيانات العميل بنجاح');
                }
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('حفظ التعديلات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddCustomerDialog() {
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _addressCtrl.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: AppTheme.modalSheetPadding(ctx, horizontal: 20, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'إضافة عميل جديد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم العميل *',
                hintText: 'أدخل اسم العميل (إجباري)',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف (اختياري)',
                hintText: 'رقم التليفون أو المحمول',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'العنوان (اختياري)',
                hintText: 'عنوان العميل أو المنطقة',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: AppTheme.royalGold,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                final name = _nameCtrl.text.trim();
                if (name.isEmpty) {
                  AppNotification.showError(ctx, 'يرجى إدخال اسم العميل أولاً');
                  return;
                }
                final db = await DBHelper.instance.database;
                await db.insert('customers', {
                  'name': name,
                  'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
                  'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
                });
                _nameCtrl.clear();
                _phoneCtrl.clear();
                _addressCtrl.clear();
                AppEvents.instance.notifyAll();
                if (mounted) {
                  Navigator.pop(ctx);
                  AppNotification.showSuccess(context, 'تم إضافة العميل بنجاح');
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('حفظ العميل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: _customers.isEmpty
            ? const RefreshableEmptyView(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'لا يوجد عملاء مسجلين حالياً.\nاضغط على (إضافة عميل) لإضافة أول عميل.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 80),
              itemCount: _customers.length,
              itemBuilder: (ctx, i) {
                final c = _customers[i];
                final phone = (c['phone'] != null && c['phone'].toString().isNotEmpty) ? c['phone'] : '-';
                final address = (c['address'] != null && c['address'].toString().isNotEmpty) ? c['address'] : '-';
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.primaryNavy,
                      foregroundColor: AppTheme.royalGold,
                      child: Icon(Icons.person),
                    ),
                    title: Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('هاتف: $phone | عنوان: $address'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryNavy, size: 24),
                          tooltip: 'تعديل بيانات العميل',
                          onPressed: () => _openEditCustomerDialog(c),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 22),
                          tooltip: 'حذف العميل',
                          onPressed: () => _confirmDeleteCustomer(context, c),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: AppTheme.royalGold,
        onPressed: _openAddCustomerDialog,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('إضافة عميل', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
