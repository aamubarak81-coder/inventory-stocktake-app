import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نظام الجرد الذكي'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text('مرحباً بك', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            _MenuButton(
              icon: Icons.list_alt,
              label: 'المنتجات',
              color: Colors.blue,
              onTap: () {
                // TODO: رح نرجع نفعل هاد بعد ما نفصل ProductsScreen
              },
            ),
            const SizedBox(height: 16),
            _MenuButton(
              icon: Icons.qr_code_scanner,
              label: 'بدء الجرد',
              color: Colors.green,
              onTap: () {
                // TODO: رح نرجع نفعل هاد بعد ما نفصل StocktakeScreen
              },
            ),
            const SizedBox(height: 16),
            _MenuButton(
              icon: Icons.bar_chart,
              label: 'نتائج الجرد',
              color: Colors.orange,
              onTap: () {
                // TODO: رح نرجع نفعل هاد بعد ما نفصل ResultsScreen
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
      ),
    );
  }
}
