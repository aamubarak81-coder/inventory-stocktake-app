import 'screens/main_navigation_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // طھظ… ط¯ظ…ط¬ ط§ظ„ط±ط§ط¨ط· ظ‡ظ†ط§ ظƒظƒظ„ظ…ط© ظˆط§ط­ط¯ط© ظ…طھطµظ„ط© طھظ…ط§ظ…ط§ظ‹ ط¨ط¯ظˆظ† ط£ظٹ ظ…ط³ط§ظپط§طھ
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
      title: 'ظ†ط¸ط§ظ… ط§ظ„ط¬ط±ط¯ ط§ظ„ط°ظƒظٹ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: LoginScreen(),
    );
  }
}
