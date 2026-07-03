import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/product_model.dart';
import 'models/stocktake_model.dart';
import 'services/hive_service.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة Hive (التخزين المحلي)
  await Hive.initFlutter();

  // 2. تسجيل الموديلات (Adapters) عشان Hive يعرف يخزنها
  Hive.registerAdapter(ProductModelAdapter());
  Hive.registerAdapter(StocktakeModelAdapter());

  // 3. فتح الصناديق (Boxes) قبل ما يشتغل أي شاشة
  await Hive.openBox<ProductModel>(HiveService.productBoxName);
  await Hive.openBox<StocktakeModel>(HiveService.stocktakeBoxName);

  // 4. تهيئة الاتصال بقاعدة بيانات Supabase
  await Supabase.initialize(
    url: 'https://dqyorsbkxxgjctprjjdw.supabase.co',
    publishableKey: 'sb_publishable_8RMW-u8_2wdFG_pa4RVjYA_mJ5yx1OF',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام الجرد الذكي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
