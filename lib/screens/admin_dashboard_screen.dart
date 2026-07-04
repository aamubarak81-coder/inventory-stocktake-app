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

  final List<Widget> _screens = const [
    _DashboardTab(),
    _BranchesTab(),
    _WarehousesTab(),
    _EmployeesTab(),
    _PermissionsTab(),
    _ReportsTab(),
  ];

  final List<NavigationRailDestination> _destinations = const [
    NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('الرئيسية')),
    NavigationRailDestination(icon: Icon(Icons.business), label: Text('الفروع')),
    NavigationRailDestination(icon: Icon(Icons.warehouse), label: Text('المستودعات')),
    NavigationRailDestination(icon: Icon(Icons.people), label: Text('الموظفين')),
    NavigationRailDestination(icon: Icon(Icons.security), label: Text('الصلاحيات')),
    NavigationRailDestination(icon: Icon(Icons.bar_chart), label: Text('التقارير')),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              labelType: NavigationRailLabelType.all,
              destinations: _destinations,
              backgroundColor: Colors.blue[50],
              selectedIconTheme: const IconThemeData(color: Colors.blue),
              selectedLabelTextStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: _screens[_selectedIndex]),
          ],
        ),
      ),
    );
  }
}

// ==================== تبويب الرئيسية ====================
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  int _warehouseCount = 0;
  int _employeeCount = 0;
  int _stocktakeCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final warehouses = await AdminService.getWarehouses();
    final employees = await AdminService.getEmployees();
    final stocktakes = HiveService.getStocktakes();
    if (mounted) {
      setState(() {
        _warehouseCount = warehouses.length;
        _employeeCount = employees.length;
        _stocktakeCount = stocktakes.length;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = HiveService.getProducts();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('لوحة تحكم المدير',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _DashboardCard(icon: Icons.inventory_2, title: 'المنتجات',
                    count: products.length.toString(), color: Colors.blue),
                _DashboardCard(icon: Icons.warehouse, title: 'المستودعات',
                    count: _warehouseCount.toString(), color: Colors.green),
                _DashboardCard(icon: Icons.people, title: 'الموظفين',
                    count: _employeeCount.toString(), color: Colors.orange),
                _DashboardCard(icon: Icons.qr_code_scanner, title: 'عمليات الجرد',
                    count: _stocktakeCount.toString(), color: Colors.purple),
              ],
            ),
          const SizedBox(height: 24),
          const Text('آخر عمليات الجرد',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: () {
              final stocktakes = HiveService.getStocktakes().reversed.take(10).toList();
              if (stocktakes.isEmpty) {
                return const Center(
                    child: Text('لا توجد عمليات جرد بعد',
                        style: TextStyle(color: Colors.grey)));
              }
              return ListView.builder(
                itemCount: stocktakes.length,
                itemBuilder: (context, index) {
                  final s = stocktakes[index];
                  final diff = s.expectedQuantity != null
                      ? s.scannedQuantity - s.expectedQuantity!
                      : 0;
                  return ListTile(
                    leading: Icon(
                      diff == 0 ? Icons.check_circle : diff > 0 ? Icons.add_circle : Icons.remove_circle,
                      color: diff == 0 ? Colors.green : diff > 0 ? Colors.teal : Colors.red,
                    ),
                    title: Text(s.barcode.isNotEmpty ? s.barcode : s.productId),
                    subtitle: Text('الكمية: ${s.scannedQuantity} | ${s.isSynced ? "✅ متزامن" : "🕐 غير متزامن"}'),
                  );
                },
              );
            }(),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String count;
  final Color color;

  const _DashboardCard({required this.icon, required this.title,
      required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 12),
          Text(count, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
        ],
      ),
    );
  }
}

// ==================== تبويب الفروع ====================
class _BranchesTab extends StatefulWidget {
  const _BranchesTab();

  @override
  State<_BranchesTab> createState() => _BranchesTabState();
}

class _BranchesTabState extends State<_BranchesTab> {
  List<Map<String, dynamic>> _orgs = [];
  bool _loading = true;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await AdminService.getOrganizations();
    if (mounted) setState(() { _orgs = data; _loading = false; });
  }

  void _showAddDialog() {
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة فرع / شركة جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم الفرع *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _phoneController,
                decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _emailController,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final error = await AdminService.addOrganization(
                name: _nameController.text.trim(),
                phone: _phoneController.text.trim(),
                email: _emailController.text.trim(),
              );
              if (error != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $error'), backgroundColor: Colors.red));
              } else {
                _load();
              }
            },
            child: const Text('إضافة'),
          ),
        ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إدارة الفروع والشركات',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add),
                label: const Text('إضافة فرع'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _orgs.isEmpty
                    ? const Center(child: Text('لا توجد فروع مسجلة بعد', style: TextStyle(color: Colors.grey, fontSize: 16)))
                    : ListView.builder(
                        itemCount: _orgs.length,
                        itemBuilder: (context, index) {
                          final org = _orgs[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Text((org['name'] ?? '?')[0],
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(org['name'] ?? '-',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (org['phone'] != null) Text('📞 ${org['phone']}'),
                                  if (org['email'] != null) Text('✉️ ${org['email']}'),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(org['id'].toString().substring(0, 8) + '...'),
                                backgroundColor: Colors.grey[200],
                              ),
                              isThreeLine: true,
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

// ==================== تبويب المستودعات ====================
class _WarehousesTab extends StatefulWidget {
  const _WarehousesTab();

  @override
  State<_WarehousesTab> createState() => _WarehousesTabState();
}

class _WarehousesTabState extends State<_WarehousesTab> {
  List<Map<String, dynamic>> _warehouses = [];
  bool _loading = true;
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await AdminService.getWarehouses();
    if (mounted) setState(() { _warehouses = data; _loading = false; });
  }

  void _showAddDialog() {
    _nameController.clear();
    _locationController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مستودع جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم المستودع *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _locationController,
                decoration: const InputDecoration(labelText: 'الموقع / العنوان', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final error = await AdminService.addWarehouse(
                name: _nameController.text.trim(),
                location: _locationController.text.trim(),
              );
              if (error != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $error'), backgroundColor: Colors.red));
              } else {
                _load();
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(String id, String name) async {
    final confirm = await showDialog<bool>(
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
    if (confirm == true) {
      await AdminService.deleteWarehouse(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إدارة المستودعات',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add),
                label: const Text('إضافة مستودع'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _warehouses.isEmpty
                    ? const Center(child: Text('لا توجد مستودعات مسجلة بعد', style: TextStyle(color: Colors.grey, fontSize: 16)))
                    : ListView.builder(
                        itemCount: _warehouses.length,
                        itemBuilder: (context, index) {
                          final w = _warehouses[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.green,
                                child: Icon(Icons.warehouse, color: Colors.white),
                              ),
                              title: Text(w['name'] ?? '-',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(w['location'] ?? 'لم يحدد الموقع',
                                  style: const TextStyle(color: Colors.grey)),
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

// ==================== تبويب الموظفين ====================
class _EmployeesTab extends StatefulWidget {
  const _EmployeesTab();

  @override
  State<_EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends State<_EmployeesTab> {
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await AdminService.getEmployees();
    if (mounted) setState(() { _employees = data; _loading = false; });
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'admin': return Colors.purple;
      case 'manager': return Colors.blue;
      case 'super_admin': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin': return 'مدير';
      case 'manager': return 'مشرف';
      case 'super_admin': return 'مدير عام';
      default: return 'موظف';
    }
  }

  void _showEditRoleDialog(Map<String, dynamic> emp) {
    String selectedRole = emp['role'] ?? 'employee';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('تعديل صلاحية: ${emp['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['employee', 'manager', 'admin', 'super_admin'].map((role) {
              return RadioListTile<String>(
                title: Text(_roleLabel(role)),
                value: role,
                groupValue: selectedRole,
                onChanged: (val) => setDialogState(() => selectedRole = val!),
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await AdminService.updateEmployeeRole(
                  employeeId: emp['id'],
                  role: selectedRole,
                  isSuperAdmin: selectedRole == 'super_admin',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الموظفين (${_employees.length})',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'تحديث'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _employees.isEmpty
                    ? const Center(child: Text('لا يوجد موظفون مسجلون', style: TextStyle(color: Colors.grey, fontSize: 16)))
                    : ListView.builder(
                        itemCount: _employees.length,
                        itemBuilder: (context, index) {
                          final emp = _employees[index];
                          final role = emp['role'] as String?;
                          final isSuperAdmin = emp['is_super_admin'] == true;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _roleColor(role),
                                child: Text(
                                  (emp['name'] ?? '?').toString().isNotEmpty
                                      ? (emp['name'] as String)[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(emp['name'] ?? '-',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  if (isSuperAdmin)
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                ],
                              ),
                              subtitle: Text(
                                'المعرف: ${emp['id'].toString().substring(0, 12)}...',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(
                                    label: Text(_roleLabel(role),
                                        style: TextStyle(color: _roleColor(role), fontSize: 12)),
                                    backgroundColor: _roleColor(role).withOpacity(0.1),
                                    side: BorderSide(color: _roleColor(role).withOpacity(0.3)),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _showEditRoleDialog(emp),
                                    tooltip: 'تعديل الصلاحية',
                                  ),
                                ],
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

// ==================== تبويب الصلاحيات ====================
class _PermissionsTab extends StatefulWidget {
  const _PermissionsTab();

  @override
  State<_PermissionsTab> createState() => _PermissionsTabState();
}

class _PermissionsTabState extends State<_PermissionsTab> {
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  final List<String> _allPermissions = ['home', 'products', 'stocktake', 'results', 'reports'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await AdminService.getEmployees();
    if (mounted) setState(() { _employees = data; _loading = false; });
  }

  String _permLabel(String perm) {
    const labels = {
      'home': '🏠 الرئيسية', 'products': '📦 المنتجات',
      'stocktake': '📱 الجرد', 'results': '📊 النتائج', 'reports': '📈 التقارير',
    };
    return labels[perm] ?? perm;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إدارة صلاحيات الموظفين',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('حدد الدور المناسب لكل موظف لتحديد صلاحياته',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _employees.isEmpty
                    ? const Center(child: Text('لا يوجد موظفون', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _employees.length,
                        itemBuilder: (context, index) {
                          final emp = _employees[index];
                          final role = emp['role'] as String? ?? 'employee';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Text(
                                  (emp['name'] ?? '?').toString().isNotEmpty
                                      ? (emp['name'] as String)[0]
                                      : '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(emp['name'] ?? '-',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('الدور الحالي: ${_roleLabel(role)}'),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('الشاشات المتاحة بناءً على الدور:',
                                          style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _allPermissions.map((perm) {
                                          final hasAccess = role == 'admin' || role == 'super_admin' ||
                                              (role == 'manager' && perm != 'reports') ||
                                              (role == 'employee' && (perm == 'home' || perm == 'stocktake'));
                                          return Chip(
                                            label: Text(_permLabel(perm)),
                                            backgroundColor: hasAccess ? Colors.green[100] : Colors.grey[200],
                                            avatar: Icon(
                                              hasAccess ? Icons.check_circle : Icons.cancel,
                                              color: hasAccess ? Colors.green : Colors.grey,
                                              size: 16,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
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

  String _roleLabel(String role) {
    const labels = {'admin': 'مدير', 'manager': 'مشرف', 'super_admin': 'مدير عام', 'employee': 'موظف'};
    return labels[role] ?? role;
  }
}

// ==================== تبويب التقارير ====================
class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    return const ReportsScreen();
  }
}
