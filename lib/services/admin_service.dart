import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class AdminService {
  static SupabaseClient get _client => Supabase.instance.client;

  // ==================== الفروع (Organizations) ====================

  static Future<List<Map<String, dynamic>>> getOrganizations() async {
    try {
      final isSuperAdmin = await AuthService.getEmployeeRole();
      if (isSuperAdmin == 'super_admin') {
        // المدير العام يرى كل الشركات
        final response = await _client
            .from('organizations')
            .select()
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      } else {
        // المدير العادي يرى شركته فقط
        final orgId = await AuthService.getOrgId();
        if (orgId == null) return [];
        final response = await _client
            .from('organizations')
            .select()
            .eq('id', orgId);
        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      return [];
    }
  }

  static Future<String?> addOrganization({
    required String name,
    String? phone,
    String? email,
  }) async {
    try {
      await _client.from('organizations').insert({
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ==================== المستودعات (Warehouses) ====================

  static Future<List<Map<String, dynamic>>> getWarehouses() async {
    try {
      final orgId = await AuthService.getOrgId();
      if (orgId == null) return [];
      final response = await _client
          .from('warehouses')
          .select()
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
  }) async {
    try {
      final orgId = await AuthService.getOrgId();
      if (orgId == null) return 'لم يتم تحديد المنظمة';
      await _client.from('warehouses').insert({
        'org_id': orgId,
        'name': name,
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
          .select('id, name, role, is_super_admin, warehouse_id, created_at')
          .eq('org_id', orgId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  static Future<String?> updateEmployeeRole({
    required String employeeId,
    required String role,
    bool isSuperAdmin = false,
  }) async {
    try {
      await _client.from('employees').update({
        'role': role,
        'is_super_admin': isSuperAdmin,
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
