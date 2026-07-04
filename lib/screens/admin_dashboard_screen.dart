import 'package:flutter/material.dart';
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
    return Scaffold(
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
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('لوحة تحكم المدير', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _DashboardCard(
                icon: Icons.inventory_2,
                title: 'المنتجات',
                count: '20,000+',
                color: Colors.blue,
                onTap: () {},
              ),
              _DashboardCard(
                icon: Icons.warehouse,
                title: 'المستودعات',
                count: '5',
                color: Colors.green,
                onTap: () {},
              ),
              _DashboardCard(
                icon: Icons.people,
                title: 'الموظفين',
                count: '12',
                color: Colors.orange,
                onTap: () {},
              ),
              _DashboardCard(
                icon: Icons.qr_code_scanner,
                title: 'عمليات الجرد',
                count: '156',
                color: Colors.purple,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('آخر النشاطات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: const [
                ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text('تم إكمال جرد مستودع الرياض'),
                  subtitle: Text('من قبل: أحمد - منذ 2 ساعة'),
                ),
                ListTile(
                  leading: Icon(Icons.warning, color: Colors.orange),
                  title: Text('فروقات في جرد مستودع جدة'),
                  subtitle: Text('من قبل: خالد - منذ 5 ساعات'),
                ),
                ListTile(
                  leading: Icon(Icons.person_add, color: Colors.blue),
                  title: Text('تم إضافة موظف جديد: سارة'),
                  subtitle: Text('منذ يوم واحد'),
                ),
              ],
            ),
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
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
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
      ),
    );
  }
}

class _BranchesTab extends StatelessWidget {
  const _BranchesTab();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('إدارة الفروع - قريباً', style: TextStyle(fontSize: 20)));
  }
}

class _WarehousesTab extends StatelessWidget {
  const _WarehousesTab();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('إدارة المستودعات - قريباً', style: TextStyle(fontSize: 20)));
  }
}

class _EmployeesTab extends StatelessWidget {
  const _EmployeesTab();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('إدارة الموظفين - قريباً', style: TextStyle(fontSize: 20)));
  }
}

class _PermissionsTab extends StatefulWidget {
  const _PermissionsTab();

  @override
  State<_PermissionsTab> createState() => _PermissionsTabState();
}

class _PermissionsTabState extends State<_PermissionsTab> {
  final List<Map<String, dynamic>> _employees = [
    {'name': 'أحمد', 'email': 'ahmed@test.com', 'role': 'employee', 'permissions': ['stocktake', 'results']},
    {'name': 'خالد', 'email': 'khaled@test.com', 'role': 'employee', 'permissions': ['stocktake']},
    {'name': 'سارة', 'email': 'sara@test.com', 'role': 'employee', 'permissions': ['stocktake', 'results', 'reports']},
  ];

  final List<String> _allPermissions = ['home', 'products', 'stocktake', 'results', 'reports'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إدارة صلاحيات الموظفين', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('حدد الشاشات التي يمكن للموظف الوصول إليها', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _employees.length,
              itemBuilder: (context, index) {
                final emp = _employees[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(emp['name'][0], style: const TextStyle(color: Colors.white)),
                    ),
                    title: Text(emp['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(emp['email']),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('الصلاحيات المتاحة:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _allPermissions.map((perm) {
                                final isGranted = (emp['permissions'] as List).contains(perm);
                                return FilterChip(
                                  label: Text(_permLabel(perm)),
                                  selected: isGranted,
                                  selectedColor: Colors.green[100],
                                  checkmarkColor: Colors.green,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        (emp['permissions'] as List).add(perm);
                                      } else {
                                        (emp['permissions'] as List).remove(perm);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('تم حفظ صلاحيات ${emp['name']}')),
                                    );
                                  },
                                  icon: const Icon(Icons.save),
                                  label: const Text('حفظ الصلاحيات'),
                                ),
                              ],
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

  String _permLabel(String perm) {
    final labels = {
      'home': '🏠 الرئيسية',
      'products': '📦 المنتجات',
      'stocktake': '📱 الجرد',
      'results': '📊 النتائج',
      'reports': '📈 التقارير',
    };
    return labels[perm] ?? perm;
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    return const ReportsScreen();
  }
}