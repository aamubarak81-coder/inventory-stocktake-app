import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../services/hive_service.dart';
import 'reports_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _DashboardTab(),
      _BranchesTab(key: UniqueKey()),
      _EmployeesTab(key: UniqueKey()),
      const _PermissionsTab(),
      const _ReportsTab(),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.blue[50],
              selectedIconTheme: const IconThemeData(color: Colors.blue),
              selectedLabelTextStyle:
                  const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('الرئيسية')),
                NavigationRailDestination(icon: Icon(Icons.business), label: Text('الفروع')),
                NavigationRailDestination(icon: Icon(Icons.people), label: Text('الموظفين')),
                NavigationRailDestination(icon: Icon(Icons.security), label: Text('الصلاحيات')),
                NavigationRailDestination(icon: Icon(Icons.bar_chart), label: Text('التقارير')),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: screens[_selectedIndex]),
          ],
        ),
      ),
    );
  }
}

// ==================== الرئيسية ====================
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();
  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  int _bCount = 0, _wCount = 0, _eCount = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final b = await AdminService.getBranches();
    final w = await AdminService.getWarehouses();
    final e = await AdminService.getEmployees();
    if (mounted) setState(() { _bCount = b.length; _wCount = w.length; _eCount = e.length; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final products = HiveService.getProducts();
    final stocktakes = HiveService.getStocktakes();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('لوحة تحكم المدير',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        if (_loading) const CircularProgressIndicator()
        else Wrap(spacing: 16, runSpacing: 16, children: [
          _KpiCard('المنتجات', products.length.toString(), Icons.inventory_2, Colors.blue),
          _KpiCard('الفروع', _bCount.toString(), Icons.business, Colors.indigo),
          _KpiCard('المستودعات', _wCount.toString(), Icons.warehouse, Colors.green),
          _KpiCard('الموظفين', _eCount.toString(), Icons.people, Colors.orange),
          _KpiCard('عمليات الجرد', stocktakes.length.toString(), Icons.qr_code_scanner, Colors.purple),
        ]),
        const SizedBox(height: 24),
        const Text('آخر عمليات الجرد',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: stocktakes.isEmpty
              ? const Center(child: Text('لا توجد عمليات جرد بعد', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: stocktakes.length > 15 ? 15 : stocktakes.length,
                  itemBuilder: (_, i) {
                    final s = stocktakes.reversed.toList()[i];
                    final diff = s.expectedQuantity != null
                        ? s.scannedQuantity - s.expectedQuantity! : 0;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        diff == 0 ? Icons.check_circle : diff > 0 ? Icons.add_circle : Icons.remove_circle,
                        color: diff == 0 ? Colors.green : diff > 0 ? Colors.teal : Colors.red,
                      ),
                      title: Text(s.barcode.isNotEmpty ? s.barcode : s.productId,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text('الكمية: ${s.scannedQuantity} | ${s.isSynced ? "✅ متزامن" : "🕐 غير متزامن"}'),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title, count;
  final IconData icon;
  final Color color;
  const _KpiCard(this.title, this.count, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ]),
    );
  }
}

// ==================== الفروع ومستودعاتها ====================
class _BranchesTab extends StatefulWidget {
  const _BranchesTab({super.key});
  @override
  State<_BranchesTab> createState() => _BranchesTabState();
}

class _BranchesTabState extends State<_BranchesTab> {
  List<Map<String, dynamic>> _branches = [];
  Map<int, List<Map<String, dynamic>>> _warehousesByBranch = {};
  bool _loading = true;
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _nameCtrl.dispose(); _locationCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final branches = await AdminService.getBranches();
    final allWarehouses = await AdminService.getWarehouses();

    // تجميع المستودعات تحت فروعها
    final Map<int, List<Map<String, dynamic>>> grouped = {};
    for (final w in allWarehouses) {
      final bid = w['branch_id'] as int?;
      if (bid != null) {
        grouped.putIfAbsent(bid, () => []).add(w);
      }
    }
    if (mounted) setState(() { _branches = branches; _warehousesByBranch = grouped; _loading = false; });
  }

  void _showAddBranchDialog() {
    _nameCtrl.clear(); _locationCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة فرع جديد'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم الفرع *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _locationCtrl,
              decoration: const InputDecoration(labelText: 'الموقع / المدينة', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (_nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final error = await AdminService.addBranch(
                name: _nameCtrl.text.trim(),
                location: _locationCtrl.text.trim(),
              );
              if (error != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $error'), backgroundColor: Colors.red));
              } else { _load(); }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showAddWarehouseDialog(int branchId, String branchName) {
    _nameCtrl.clear(); _locationCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة مستودع لـ "$branchName"'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم المستودع *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _locationCtrl,
              decoration: const InputDecoration(labelText: 'الموقع / العنوان', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (_nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final error = await AdminService.addWarehouse(
                name: _nameCtrl.text.trim(),
                location: _locationCtrl.text.trim(),
                branchId: branchId,
              );
              if (error != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $error'), backgroundColor: Colors.red));
              } else { _load(); }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBranch(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('حذف فرع "$name" سيحذف مستودعاته أيضاً. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) { await AdminService.deleteBranch(id); _load(); }
  }

  Future<void> _deleteWarehouse(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف مستودع "$name"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) { await AdminService.deleteWarehouse(id); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('الفروع (${_branches.length})',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ElevatedButton.icon(
            onPressed: _showAddBranchDialog,
            icon: const Icon(Icons.add_business),
            label: const Text('إضافة فرع'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
          ),
        ]),
        const SizedBox(height: 4),
        const Text('اضغط على الفرع لعرض مستودعاته أو إضافة مستودع جديد',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _branches.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.business_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('لا توجد فروع بعد', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showAddBranchDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('أضف أول فرع'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                        ),
                      ]),
                    )
                  : ListView.builder(
                      itemCount: _branches.length,
                      itemBuilder: (_, i) {
                        final branch = _branches[i];
                        final branchId = branch['id'] as int;
                        final warehouses = _warehousesByBranch[branchId] ?? [];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo,
                              child: Text(
                                (branch['name'] ?? '?')[0],
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(branch['name'] ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Text(
                              '${branch['location'] ?? 'لم يحدد الموقع'} • ${warehouses.length} مستودع',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.green),
                                tooltip: 'إضافة مستودع',
                                onPressed: () => _showAddWarehouseDialog(branchId, branch['name'] ?? ''),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'حذف الفرع',
                                onPressed: () => _deleteBranch(branchId, branch['name'] ?? ''),
                              ),
                            ]),
                            children: [
                              if (warehouses.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(children: [
                                    const Icon(Icons.info_outline, color: Colors.grey, size: 16),
                                    const SizedBox(width: 8),
                                    const Text('لا توجد مستودعات لهذا الفرع',
                                        style: TextStyle(color: Colors.grey)),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: () => _showAddWarehouseDialog(branchId, branch['name'] ?? ''),
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('إضافة مستودع'),
                                    ),
                                  ]),
                                )
                              else
                                ...warehouses.map((w) => ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 2),
                                  leading: const Icon(Icons.warehouse, color: Colors.green, size: 22),
                                  title: Text(w['name'] ?? '-',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(w['location'] ?? 'لم يحدد الموقع',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                    onPressed: () => _deleteWarehouse(w['id'], w['name'] ?? ''),
                                  ),
                                )),
                              // زر إضافة مستودع في أسفل كل فرع
                              if (warehouses.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(32, 0, 16, 12),
                                  child: Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: TextButton.icon(
                                      onPressed: () => _showAddWarehouseDialog(branchId, branch['name'] ?? ''),
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('إضافة مستودع آخر'),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

// ==================== الموظفين ====================
class _EmployeesTab extends StatefulWidget {
  const _EmployeesTab({super.key});
  @override
  State<_EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends State<_EmployeesTab> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _warehouses = [];
  bool _loading = true;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _selectedRole = 'employee';
  String? _selectedWarehouseId;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose();
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final e = await AdminService.getEmployees();
    final w = await AdminService.getWarehouses();
    if (mounted) setState(() { _employees = e; _warehouses = w; _loading = false; });
  }

  Color _roleColor(String? r) {
    switch (r) {
      case 'super_admin': return Colors.red;
      case 'admin': return Colors.purple;
      case 'manager': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _roleLabel(String? r) {
    const m = {'super_admin': 'مدير عام', 'admin': 'مدير', 'manager': 'مشرف', 'employee': 'موظف'};
    return m[r] ?? 'موظف';
  }

  String? _warehouseName(String? wid) {
    if (wid == null) return null;
    final w = _warehouses.where((x) => x['id'] == wid).toList();
    return w.isNotEmpty ? w.first['name'] : null;
  }

  void _showAddDialog() {
    _emailCtrl.clear(); _passCtrl.clear(); _nameCtrl.clear(); _phoneCtrl.clear();
    _selectedRole = 'employee'; _selectedWarehouseId = null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('إضافة موظف جديد'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _passCtrl, obscureText: true,
                  decoration: const InputDecoration(labelText: 'كلمة المرور *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: 'الدور / الصلاحية', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'employee', child: Text('موظف - جرد فقط')),
                  DropdownMenuItem(value: 'manager', child: Text('مشرف - جرد + نتائج + تقارير')),
                  DropdownMenuItem(value: 'admin', child: Text('مدير - كل الصلاحيات')),
                  DropdownMenuItem(value: 'super_admin', child: Text('مدير عام - كل شيء')),
                ],
                onChanged: (v) => setS(() => _selectedRole = v!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedWarehouseId,
                decoration: const InputDecoration(labelText: 'المستودع المخصص (اختياري)', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('بدون مستودع محدد')),
                  ..._warehouses.map((w) => DropdownMenuItem(
                    value: w['id'] as String,
                    child: Text(w['name'] ?? '-'),
                  )),
                ],
                onChanged: (v) => setS(() => _selectedWarehouseId = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (_nameCtrl.text.trim().isEmpty ||
                    _emailCtrl.text.trim().isEmpty ||
                    _passCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('يرجى ملء الحقول الإلزامية *')));
                  return;
                }
                Navigator.pop(ctx);
                final error = await AdminService.addEmployee(
                  email: _emailCtrl.text.trim(),
                  password: _passCtrl.text,
                  name: _nameCtrl.text.trim(),
                  role: _selectedRole,
                  phone: _phoneCtrl.text.trim(),
                  warehouseId: _selectedWarehouseId,
                );
                if (error != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $error'), backgroundColor: Colors.red));
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ تم إضافة الموظف بنجاح'), backgroundColor: Colors.green));
                  _load();
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> emp) {
    String role = emp['role'] ?? 'employee';
    String? warehouseId = emp['warehouse_id'] as String?;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('تعديل: ${emp['name']}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: role,
              decoration: const InputDecoration(labelText: 'الدور / الصلاحية', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'employee', child: Text('موظف - جرد فقط')),
                DropdownMenuItem(value: 'manager', child: Text('مشرف - جرد + نتائج + تقارير')),
                DropdownMenuItem(value: 'admin', child: Text('مدير - كل الصلاحيات')),
                DropdownMenuItem(value: 'super_admin', child: Text('مدير عام - كل شيء')),
              ],
              onChanged: (v) => setS(() => role = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: warehouseId,
              decoration: const InputDecoration(labelText: 'المستودع المخصص', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('بدون مستودع')),
                ..._warehouses.map((w) => DropdownMenuItem(
                  value: w['id'] as String,
                  child: Text(w['name'] ?? '-'),
                )),
              ],
              onChanged: (v) => setS(() => warehouseId = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await AdminService.updateEmployee(
                  employeeId: emp['id'],
                  role: role,
                  warehouseId: warehouseId,
                );
                _load();
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('الموظفين (${_employees.length})',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Row(children: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'تحديث'),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('إضافة موظف'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            ),
          ]),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _employees.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('لا يوجد موظفون بعد', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showAddDialog,
                          icon: const Icon(Icons.person_add),
                          label: const Text('أضف أول موظف'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        ),
                      ]),
                    )
                  : ListView.builder(
                      itemCount: _employees.length,
                      itemBuilder: (_, i) {
                        final emp = _employees[i];
                        final role = emp['role'] as String?;
                        final wName = _warehouseName(emp['warehouse_id'] as String?);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _roleColor(role),
                              child: Text(
                                (emp['name'] ?? '?').toString().isNotEmpty
                                    ? (emp['name'] as String)[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Row(children: [
                              Text(emp['name'] ?? '-',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 6),
                              if (emp['is_super_admin'] == true)
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                            ]),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (emp['email'] != null)
                                  Text(emp['email'], style: const TextStyle(fontSize: 12)),
                                if (emp['phone'] != null)
                                  Text('📞 ${emp['phone']}', style: const TextStyle(fontSize: 12)),
                                if (wName != null)
                                  Text('🏭 $wName',
                                      style: const TextStyle(fontSize: 12, color: Colors.green)),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              Chip(
                                label: Text(_roleLabel(role),
                                    style: TextStyle(color: _roleColor(role), fontSize: 11)),
                                backgroundColor: _roleColor(role).withOpacity(0.1),
                                side: BorderSide(color: _roleColor(role).withOpacity(0.3)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _showEditDialog(emp),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

// ==================== الصلاحيات ====================
class _PermissionsTab extends StatefulWidget {
  const _PermissionsTab();
  @override
  State<_PermissionsTab> createState() => _PermissionsTabState();
}

class _PermissionsTabState extends State<_PermissionsTab> {
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await AdminService.getEmployees();
    if (mounted) setState(() { _employees = data; _loading = false; });
  }

  List<_PermItem> _permsForRole(String role) {
    const all = [
      _PermItem('home', '🏠 الرئيسية'),
      _PermItem('products', '📦 المنتجات'),
      _PermItem('stocktake', '📱 الجرد'),
      _PermItem('results', '📊 النتائج'),
      _PermItem('reports', '📈 التقارير'),
      _PermItem('admin', '⚙️ الإدارة'),
    ];
    final granted = {
      'employee': {'home', 'stocktake'},
      'manager': {'home', 'products', 'stocktake', 'results', 'reports'},
      'admin': {'home', 'products', 'stocktake', 'results', 'reports', 'admin'},
      'super_admin': {'home', 'products', 'stocktake', 'results', 'reports', 'admin'},
    }[role] ?? {'home', 'stocktake'};

    return all.map((p) => _PermItem(p.key, p.label, has: granted.contains(p.key))).toList();
  }

  String _roleLabel(String? r) {
    const m = {'super_admin': 'مدير عام', 'admin': 'مدير', 'manager': 'مشرف', 'employee': 'موظف'};
    return m[r] ?? 'موظف';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('الصلاحيات حسب الدور',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('الصلاحيات تُحدد تلقائياً بناءً على دور الموظف — لتغيير الصلاحيات غيّر الدور من تبويب الموظفين',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _employees.isEmpty
                  ? const Center(child: Text('لا يوجد موظفون', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _employees.length,
                      itemBuilder: (_, i) {
                        final emp = _employees[i];
                        final role = emp['role'] as String? ?? 'employee';
                        final perms = _permsForRole(role);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Text(
                                (emp['name'] ?? '?').toString().isNotEmpty
                                    ? (emp['name'] as String)[0] : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(emp['name'] ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('الدور: ${_roleLabel(role)}'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Wrap(
                                  spacing: 8, runSpacing: 8,
                                  children: perms.map((p) => Chip(
                                    label: Text(p.label,
                                        style: TextStyle(
                                            color: p.has ? Colors.green[800] : Colors.grey,
                                            fontSize: 12)),
                                    backgroundColor: p.has ? Colors.green[50] : Colors.grey[100],
                                    avatar: Icon(
                                      p.has ? Icons.check_circle : Icons.cancel,
                                      color: p.has ? Colors.green : Colors.grey[400],
                                      size: 16,
                                    ),
                                  )).toList(),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

class _PermItem {
  final String key, label;
  final bool has;
  const _PermItem(this.key, this.label, {this.has = false});
}

// ==================== التقارير ====================
class _ReportsTab extends StatelessWidget {
  const _ReportsTab();
  @override
  Widget build(BuildContext context) => const ReportsScreen();
}
