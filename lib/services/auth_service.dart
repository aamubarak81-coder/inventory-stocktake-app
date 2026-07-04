import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;
  static final _storage = const FlutterSecureStorage();

  // تسجيل الدخول بالإيميل وكلمة السر
  static Future<String?> login(String email, String password) async {
    try {
      // 1. مصادقة عبر Supabase Auth
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = authResponse.user;
      if (user == null) {
        return 'فشل تسجيل الدخول، تأكد من البيانات';
      }

      // 2. جلب بيانات الموظف من جدول employees (نفس id تبع المصادقة)
      final employeeData = await _supabase
          .from('employees')
          .select('id, org_id, warehouse_id, name, role, is_super_admin')
          .eq('id', user.id)
          .maybeSingle();

      if (employeeData == null) {
        await _supabase.auth.signOut();
        return 'هذا الحساب غير مرتبط بأي موظف بالنظام';
      }

      // 3. تخزين البيانات محلياً بشكل آمن لاستخدامها لاحقاً
      await _storage.write(key: 'employee_id', value: employeeData['id']);
      await _storage.write(key: 'org_id', value: employeeData['org_id']);
      await _storage.write(
          key: 'warehouse_id', value: employeeData['warehouse_id'] ?? '');
      await _storage.write(key: 'employee_name', value: employeeData['name']);
      await _storage.write(key: 'employee_role', value: employeeData['role']);
      await _storage.write(
          key: 'is_super_admin',
          value: (employeeData['is_super_admin'] ?? false).toString());

      return null; // null يعني نجح تسجيل الدخول بدون أخطاء
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'حدث خطأ غير متوقع: $e';
    }
  }

  // تسجيل الخروج
  static Future<void> logout() async {
    await _supabase.auth.signOut();
    await _storage.deleteAll();
  }

  // التحقق إذا في جلسة دخول محفوظة
  static Future<bool> isLoggedIn() async {
    final session = _supabase.auth.currentSession;
    final orgId = await _storage.read(key: 'org_id');
    return session != null && orgId != null;
  }

  // دوال مساعدة لجلب بيانات المستخدم الحالي من أي مكان بالتطبيق
  static Future<String?> getOrgId() => _storage.read(key: 'org_id');
  static Future<String?> getEmployeeId() => _storage.read(key: 'employee_id');
  static Future<String?> getWarehouseId() =>
      _storage.read(key: 'warehouse_id');
  static Future<String?> getEmployeeName() =>
      _storage.read(key: 'employee_name');
  static Future<String?> getEmployeeRole() =>
      _storage.read(key: 'employee_role');
}
