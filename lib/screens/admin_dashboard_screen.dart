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
      const _BranchesTab(),
      _WarehousesTab(key: UniqueKey()),
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
              selectedLabelTextStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('الرئيسية')),
                NavigationRailDestination(icon: Icon(Icons.business), label: Text('الفروع')),
                NavigationRailDestination(icon: Icon(Icons.warehouse), label: Text('المستودعات')),
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
  int _wCount = 0, _eCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = await AdminService.getWarehouses();
    final e = await AdminService.getEmployees();
    if (mounted) setState(() { _wCount = w.length; _eCount = e.length; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final products = HiveService.getProducts();
    final stocktakes = HiveService.getStocktakes();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('لوحة تحكم المدير', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          if (_loading) const CircularProgressIndicator()
          else Wrap(spacing: 16, runSpacing: 16, children: [
            _KpiCard('المنتجات', products.length.toString(), Icons.inventory_2, Colors.blue),
            _KpiCard('المستودعات', _wCount.toString(), Icons.warehouse, Colors.green),
            _KpiCard('الموظفين', _eCount.toString(), Icons.people, Colors.orange),
            _KpiCard('عمليات الجرد', stocktakes.length.toString(), Icons.qr_code_scanner, Colors.purple),
          ]),
          const SizedBox(height: 24),
          const Text('آخر عمليات الجرد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: stocktakes.isEmpty
                ? const Center(child: Text('لا توجد عمليات جرد بعد', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: stocktakes.length > 15 ? 15 : stocktakes.length,
                    itemBuilder: (_, i) {
                      final s = stocktakes.reversed.toList()[i];
                      final diff = s.expectedQuantity != null ? s.scannedQuantity - s.expectedQuantity! : 0;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          diff == 0 ? Icons.check_circle : diff > 0 ? Icons.add_circle : Icons.remove_circle,
                          color: diff == 0 ? Colors.green : diff > 0 ? Colors.teal : Colors.red,
                        ),
                        title: Text(s.barcode.isNotEmpty ? s.barcode : s.productId, style: const TextStyle(fontSize: 13)),
                        subtitle: Text('الكمية: ${s.scannedQuantity} | ${s.isSynced ? "✅ متزامن" : "🕐 غير متزامن"}'),
                      );
                    },
                  ),
          ),
        ],
      ),
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
      width: 160,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 36, color: color),
        const SizedBox(height: 10),
        Text(count, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        Text(title, style: const TextStyle(fontSize: 13, color: Colors.black54)),
      ]),
    );
  }
}

// ==================== الفروع ====================
class _BranchesTab extends StatefulWidget {
  const _BranchesTab();
  @override
  State<_BranchesTab> createState() => _BranchesTabState();
}

class _BranchesTabState extends State<_BranchesTab> {
  List<Map<String, dynamic>> _orgs = [];
  List<Map<String, dynamic>> _warehouses = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orgs = await AdminService.getOrganizations();
    final wh = await AdminService.getWarehouses();
    if (mounted) setState(() { _orgs = orgs; _warehouses = wh; _loading = false; });
  }

  List<Map<String, dynamic>> _warehousesForBranch(dynamic branchId) {
    if (branchId == null) return [];
    return _warehouses.where((w) => w['branch_id']?.toString() == branchId.toString()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الفروع ومستودعاتها', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('كل فرع يمكن أن يحتوي على أكثر من مستودع', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _orgs.isEmpty
                    ? const Center(child: Text('لا توجد فروع مسجلة', style: TextStyle(color: Colors.grey, fontSize: 16)))
                    : ListView.builder(
                        itemCount: _orgs.length,
                        itemBuilder: (_, i) {
                          final org = _orgs[i];
                          // المستودعات التي لها branch_id أو تنتمي لهذه المنظمة
                          final orgWarehouses = _warehouses;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Text((org['name'] ?? '?')[0],
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(org['name'] ?? '-',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              subtitle: Text('${orgWarehouses.length} مستودع',
                                  style: const TextStyle(color: Colors.grey)),
                              trailing: const Icon(Icons.expand_more),
                              children: orgWarehouses.isEmpty
                                  ? [const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text('لا توجد مستودعات لهذا الفرع',
                                          style: TextStyle(color: Colors.grey)))]
                                  : orgWarehouses.map((w) => ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                                        leading: const Icon(Icons.warehouse, color: Colors.green),
                                        title: Text(w['name'] ?? '-'),
                                        subtitle: Text(w['location'] ?? 'لم يحدد الموقع',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        trailing: Chip(
                                          label: Text(w['id'].toString().substring(0, 8) + '...'),
                                          backgroundColor: Colors.grey[100],
                                        ),
                                      )).toList(),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ==================== المستودعات ====================
class _WarehousesTab extends StatefulWidget {
  const _WarehousesTab({super.key});
  @override
  State<_WarehousesTab> createState() => _WarehousesTabState();
}

class _WarehousesTabState extends State<_WarehousesTab> {
  List<Map<String, dynamic>> _warehouses = [];
  bool _loading = true;
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _branchIdCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _nameCtrl.dispose(); _locationCtrl.dispose(); _branchIdCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await AdminService.getWarehouses();
    if (mounted) setState(() { _warehouses = data; _loading = false; });
  }

  void _showAddDialog() {
    _nameCtrl.clear(); _locationCtrl.clear(); _branchIdCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مستودع جديد'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'اسم المستودع *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _locationCtrl,
              decoration: const InputDecoration(labelText: 'الموقع / العنوان', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _branchIdCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'رقم الفرع (branch_id) - اختياري', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (_nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final branchId = int.tryParse(_branchIdCtrl.text.trim());
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

  Future<void> _delete(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف "$name"؟'),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('المستودعات (${_warehouses.length})',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.add),
              label: const Text('إضافة مستودع'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _warehouses.isEmpty
                    ? const Center(child: Text('لا توجد مستودعات', style: TextStyle(color: Colors.grey, fontSize: 16)))
                    : ListView.builder(
                        itemCount: _warehouses.length,
                        itemBuilder: (_, i) {
                          final w = _warehouses[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.green,
                                child: Icon(Icons.warehouse, color: Colors.white),
                              ),
                              title: Text(w['name'] ?? '-',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(w['location'] ?? 'لم يحدد الموقع',
                                      style: const TextStyle(color: Colors.grey)),
                                  if (w['branch_id'] != null)
                                    Text('الفرع: ${w['branch_id']}',
                                        style: const TextStyle(fontSize: 11, color: Colors.blue)),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _delete(w['id'], w['name'] ?? ''),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
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
                decoration: const InputDecoration(labelText: 'الدور', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'employee', child: Text('موظف')),
                  DropdownMenuItem(value: 'manager', child: Text('مشرف')),
                  DropdownMenuItem(value: 'admin', child: Text('مدير')),
                  DropdownMenuItem(value: 'super_admin', child: Text('مدير عام')),
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
                if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
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
              decoration: const InputDecoration(labelText: 'الدور', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'employee', child: Text('موظف')),
                DropdownMenuItem(value: 'manager', child: Text('مشرف')),
                DropdownMenuItem(value: 'admin', child: Text('مدير')),
                DropdownMenuItem(value: 'super_admin', child: Text('مدير عام')),
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
                await AdminService.updateEmployeeRole(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    ? const Center(child: Text('لا يوجد موظفون', style: TextStyle(color: Colors.grey, fontSize: 16)))
                    : ListView.builder(
                        itemCount: _employees.length,
                        itemBuilder: (_, i) {
                          final emp = _employees[i];
                          final role = emp['role'] as String?;
                          final warehouseId = emp['warehouse_id'] as String?;
                          final warehouseName = warehouseId != null
                              ? _warehouses.firstWhere(
                                  (w) => w['id'] == warehouseId,
                                  orElse: () => {'name': warehouseId.substring(0, 8)})['name']
                              : null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
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
                                  if (warehouseName != null)
                                    Text('🏭 $warehouseName', style: const TextStyle(fontSize: 12, color: Colors.green)),
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
        ],
      ),
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

  // تحديد الشاشات المتاحة بناءً على الدور
  List<String> _permissionsForRole(String role) {
    switch (role) {
      case 'super_admin':
      case 'admin':
        return ['home', 'products', 'stocktake', 'results', 'reports', 'admin'];
      case 'manager':
        return ['home', 'products', 'stocktake', 'results', 'reports'];
      case 'employee':
      default:
        return ['home', 'stocktake'];
    }
  }

  String _permLabel(String p) {
    const m = {
      'home': '🏠 الرئيسية', 'products': '📦 المنتجات',
      'stocktake': '📱 الجرد', 'results': '📊 النتائج',
      'reports': '📈 التقارير', 'admin': '⚙️ الإدارة',
    };
    return m[p] ?? p;
  }

  String _roleLabel(String? r) {
    const m = {'super_admin': 'مدير عام', 'admin': 'مدير', 'manager': 'مشرف', 'employee': 'موظف'};
    return m[r] ?? 'موظف';
  }

  @override
  Widget build(BuildContext context) {
    const allPerms = ['home', 'products', 'stocktake', 'results', 'reports', 'admin'];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الصلاحيات حسب الدور',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('الصلاحيات تُحدد تلقائياً بناءً على دور الموظف',
              style: TextStyle(color: Colors.grey)),
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
                          final granted = _permissionsForRole(role);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
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
                                    children: allPerms.map((p) {
                                      final has = granted.contains(p);
                                      return Chip(
                                        label: Text(_permLabel(p),
                                            style: TextStyle(
                                                color: has ? Colors.green[800] : Colors.grey,
                                                fontSize: 12)),
                                        backgroundColor: has ? Colors.green[50] : Colors.grey[100],
                                        avatar: Icon(
                                          has ? Icons.check_circle : Icons.cancel,
                                          color: has ? Colors.green : Colors.grey[400],
                                          size: 16,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ==================== التقارير ====================
class _ReportsTab extends StatelessWidget {
  const _ReportsTab();
  @override
  Widget build(BuildContext context) => const ReportsScreen();
}
