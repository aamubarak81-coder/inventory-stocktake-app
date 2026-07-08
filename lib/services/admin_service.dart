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
      // ملاحظة مهمة: إنشاء حساب مصادقة (auth.admin.createUser) ما ينعمل
      // مباشرة من التطبيق - بيحتاج مفتاح service_role السري، وهذا
      // المفتاح ممنوع يوصل لتطبيق العميل إطلاقاً (خطر أمني كبير لو
      // انكشف). لهيك نستدعي Edge Function آمنة (create-employee) بتشتغل
      // على سيرفر Supabase وتحمل مفتاح service_role بأمان هناك بس،
      // وبتتحقق هي بنفسها إنه الطالب admin/super_admin قبل ما تنفذ.
      final response = await _client.functions.invoke(
        'create-employee',
        body: {
          'email': email,
          'password': password,
          'name': name,
          'role': role,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (warehouseId != null && warehouseId.isNotEmpty) 'warehouseId': warehouseId,
        },
      );

      final data = response.data;
      if (data is Map && data['success'] == true) {
        return null;
      }
      return data is Map ? (data['error']?.toString() ?? 'فشل غير معروف') : 'فشل غير معروف';
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error']?.toString() : null;
      return message ?? 'فشل الطلب (${e.status})';
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

  // ==================== تنبيهات فروقات الجرد (Discrepancy Alerts) ====================

  // جلب التنبيهات مع اسم وباركود المنتج المرتبط بها
  // onlyUnresolved: افتراضياً بيرجع بس التنبيهات يلي لسه ما انحلّت
  static Future<List<Map<String, dynamic>>> getDiscrepancyAlerts({
    bool onlyUnresolved = true,
  }) async {
    try {
      final orgId = await AuthService.getOrgId();
      if (orgId == null) return [];

      var query = _client
          .from('discrepancy_alerts')
          .select(
              'id, product_id, stocktake_id, scanned_quantity, expected_quantity, '
              'diff_quantity, diff_percent, trigger_reason, resolved, created_at, '
              'products(name, barcode)')
          .eq('org_id', orgId);

      if (onlyUnresolved) {
        query = query.eq('resolved', false);
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // تحديد تنبيه فرق معين كـ "تمت مراجعته وحلّه" من المدير
  static Future<String?> resolveDiscrepancyAlert(String alertId) async {
    try {
      await _client.from('discrepancy_alerts').update({
        'resolved': true,
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', alertId);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ==================== إعدادات حد تنبيه الفروقات (Threshold) ====================

  // جلب الإعدادات الحالية (null لو المنظمة لسه ما ضبطت شي - بيستخدم
  // التطبيق القيم الافتراضية 5% / 10 قطع تلقائياً بهذي الحالة)
  static Future<Map<String, dynamic>?> getAlertThresholdSettings() async {
    try {
      final orgId = await AuthService.getOrgId();
      if (orgId == null) return null;

      final row = await _client
          .from('org_settings')
          .select('alert_threshold_percent, alert_threshold_qty')
          .eq('org_id', orgId)
          .maybeSingle();

      return row;
    } catch (e) {
      return null;
    }
  }

  // ضبط أو تحديث الحد الخاص بالمنظمة (upsert: يشتغل أول مرة أو تحديث لاحق)
  static Future<String?> updateAlertThresholdSettings({
    required double percent,
    required int qty,
  }) async {
    try {
      final orgId = await AuthService.getOrgId();
      if (orgId == null) return 'لم يتم تحديد المنظمة';

      await _client.from('org_settings').upsert({
        'org_id': orgId,
        'alert_threshold_percent': percent,
        'alert_threshold_qty': qty,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
