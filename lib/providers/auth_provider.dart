import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _employeeName;
  String? _employeeRole;
  String? _orgId;

  bool get isLoggedIn => _isLoggedIn;
  String? get employeeName => _employeeName;
  String? get employeeRole => _employeeRole;
  String? get orgId => _orgId;

  Future<void> checkLoginStatus() async {
    _isLoggedIn = await AuthService.isLoggedIn();
    if (_isLoggedIn) {
      _employeeName = await AuthService.getEmployeeName();
      _employeeRole = await AuthService.getEmployeeRole();
      _orgId = await AuthService.getOrgId();
    }
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    final error = await AuthService.login(email, password);
    if (error == null) {
      await checkLoginStatus();
    }
    return error;
  }

  Future<void> logout() async {
    await AuthService.logout();
    _isLoggedIn = false;
    _employeeName = null;
    _employeeRole = null;
    _orgId = null;
    notifyListeners();
  }
}
