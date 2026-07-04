import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class AdminService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ==================== الفروع (Organizations) ====================

  static Future<List<Map<String, dynamic>>> getOrganizations() async {
    try {
      final orgId = await AuthService.getOrgId();
      if (orgId == null) return [];
      // نجلب المنظمة الحالية فقط (يمكن توسيعها لاحقاً للمدير العام)
      final response = await _client
          .from('organizations')
          .select('id, name, plan_id, created_at')
          .eq('id', orgId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // ==================== المستودعات (Warehouses) مع الفرع ====================

  static Future<List<Map<String, dynamic>>> getWarehouses() async {
    try {
      final orgId = await AuthService.getOrgId();
      if (orgId == null) return [];
      final response = await _client
          .from('warehouses')
          .select('id, name, location, branch_id, org_id, created_at')
          .eq('org_id', orgId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  static Future<String?> addWarehouse({
    required String name,
    String? location,
    int? branchId,
  }) async {
    try {
      final orgId = await AuthService.getOrgId();
      if (orgId == null) return 'لم يتم تحديد المنظمة';
      await _client.from('warehouses').insert({
        'org_id': orgId,
        'name': name,
        if (location != null && location.isNotEmpty) 'location': location,
        if (branchId != null) 'branch_id': branchId,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> deleteWarehouse(String id) async {
    try {
      await _client.from('warehouses').delete().eq('id', id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ==================== الموظفين (Employees) ====================

  static Future<List<Map<String, dynamic>>> getEmployees() async {
    try {
      final orgId = await AuthService.getOrgId();
      if (orgId == null) return [];
      final response = await _client
          .from('employees')
          .select('id, name, email, phone, role, is_super_admin, warehouse_id, created_at')
          .eq('org_id', orgId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// إضافة موظف جديد عبر Supabase Auth ثم إدراجه في جدول employees
  static Future<String?> addEmployee({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
    String? warehouseId,
  }) async {
    try {
      final orgId = await AuthService.getOrgId();
      if (orgId == null) return 'لم يتم تحديد المنظمة';

      // إنشاء حساب المصادقة
      final authResponse = await _client.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: password,
          emailConfirm: true,
        ),
      );

      final userId = authResponse.user?.id;
      if (userId == null) return 'فشل إنشاء حساب المصادقة';

      // إدراج بيانات الموظف في جدول employees
      await _client.from('employees').insert({
        'id': userId,
        'org_id': orgId,
        'name': name,
        'email': email,
        'role': role,
        'is_super_admin': role == 'super_admin',
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (warehouseId != null && warehouseId.isNotEmpty) 'warehouse_id': warehouseId,
      });

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> updateEmployeeRole({
    required String employeeId,
    required String role,
    String? warehouseId,
  }) async {
    try {
      await _client.from('employees').update({
        'role': role,
        'is_super_admin': role == 'super_admin',
        if (warehouseId != null) 'warehouse_id': warehouseId.isEmpty ? null : warehouseId,
      }).eq('id', employeeId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> deleteEmployee(String id) async {
    try {
      await _client.from('employees').delete().eq('id', id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
