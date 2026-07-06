import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'products_screen.dart';
import 'stocktake_screen.dart';
import 'results_screen.dart';
import 'reports_screen.dart';
import 'admin_dashboard_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
  }

  Future<void> _checkAdminRole() async {
    final role = await AuthService.getEmployeeRole();
    final isSuperAdmin = await AuthService.getEmployeeRole();
    setState(() {
      _isAdmin = role == 'admin' || role == 'manager' || isSuperAdmin == 'super_admin';
    });
  }

  List<Widget> get _screens => [
    HomeScreen(),
    ProductsScreen(),
    const StocktakeScreen(),
    ResultsScreen(),
    ReportsScreen(),
    if (_isAdmin) AdminDashboardScreen(),
  ];

  List<BottomNavigationBarItem> get _navItems => [
    const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
    const BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'المنتجات'),
    const BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'الجرد'),
    const BottomNavigationBarItem(icon: Icon(Icons.assessment), label: 'النتائج'),
    const BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'التقارير'),
    if (_isAdmin)
      const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'الإدارة'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex.clamp(0, _screens.length - 1),
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex.clamp(0, _screens.length - 1),
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: _navItems,
      ),
    );
  }
}
