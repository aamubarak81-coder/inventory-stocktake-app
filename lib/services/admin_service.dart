import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class AdminService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ==================== الفروع (Branches) ====================

  static Future<List<Map<String, dynamic>>> getBranches() async {
    try {
      final orgId = await AuthService.getOrgId();
      if (orgId == null) return [];
      final response = await _client
          .from('branches')
          .select('id, name, location, org_id, created_at')
          .eq('org_id', orgId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  static Future<String?> addBranch({
    required String name,
    String? location,
  }) async {
    try {
      final orgId = await AuthService.getOrgId();
      if (orgId == null) return 'لم يتم تحديد المنظمة';
      await _client.from('branches').insert({
        'org_id': orgId,
        'name': name,
        if (location != null && location.isNotEmpty) 'location': location,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> deleteBranch(int id) async {
    try {
      await _client.from('branches').delete().eq('id', id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ==================== المستودعات (Warehouses) ====================

  static Future<List<Map<String, dynamic>>> getWarehouses({int? branchId}) async {
    try {
      final orgId = await AuthService.getOrgId();
      if (orgId == null) return [];
      var query = _client
          .from('warehouses')
          .select('id, name, location, branch_id, org_id, created_at')
          .eq('org_id', orgId);
      if (branchId != null) {
        query = query.eq('branch_id', branchId);
      }
      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  static Future<String?> addWarehouse({
    required String name,
    String? location,
    required int branchId,
  }) async {
    try {
      final orgId = await AuthService.getOrgId();
      if (orgId == null) return 'لم يتم تحديد المنظمة';
      await _client.from('warehouses').insert({
        'org_id': orgId,
        'name': name,
        'branch_id': branchId,
        if (location != null && location.isNotEmpty) 'location': location,
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

      final authResponse = await _client.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: password,
          emailConfirm: true,
        ),
      );

      final userId = authResponse.user?.id;
      if (userId == null) return 'فشل إنشاء حساب المصادقة';

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

  static Future<String?> updateEmployee({
    required String employeeId,
    required String role,
    String? warehouseId,
  }) async {
    try {
      await _client.from('employees').update({
        'role': role,
        'is_super_admin': role == 'super_admin',
        'warehouse_id': (warehouseId != null && warehouseId.isNotEmpty) ? warehouseId : null,
      }).eq('id', employeeId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
