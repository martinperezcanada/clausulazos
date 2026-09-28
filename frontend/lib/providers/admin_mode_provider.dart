import 'package:flutter/foundation.dart';
import 'auth_provider.dart';

/// "Modo Admin" state shared by Home (the switch), Activity (swipe to delete) and Managers (pending
/// approvals). Turning it on is limited to the admin account's email (`AuthProvider`). This is UI only:
/// admin actions are re-checked server-side by `AdminGuard`.
class AdminModeProvider extends ChangeNotifier {
  AdminModeProvider({required AuthProvider authProvider})
      : _authProvider = authProvider;

  final AuthProvider _authProvider;

  static const _adminEmail = 'martin0345@gmail.com';

  bool _isAdminMode = false;
  bool get isAdminMode => _isAdminMode;

  bool get isAllowedAdmin =>
      (_authProvider.currentUser?.email.trim().toLowerCase() ?? '') ==
      _adminEmail;

  /// Returns true if the mode changed to `value`. For anyone but `_adminEmail`, turning it on does
  /// nothing.
  bool setAdminMode(bool value) {
    if (value && !isAllowedAdmin) return false;
    if (_isAdminMode == value) return true;
    _isAdminMode = value;
    notifyListeners();
    return true;
  }
}
