 import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        backgroundColor: Colors.orange,
      ),
      body: const Center(
        child: Text(
          'شاشة التقارير - قريباً',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
