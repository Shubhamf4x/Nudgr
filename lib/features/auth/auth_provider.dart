import 'package:flutter/material.dart';
import '../../shared/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/steps_service.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService.getInstance();
  final SyncService _syncService = SyncService.getInstance();
  final DatabaseService _db = DatabaseService.getInstance();
  AuthState _state = AuthState.initial;
  UserModel? _user;
  String? _error;

  AuthState get state => _state;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _state == AuthState.authenticated;

  bool get cloudSyncEnabled => _user?.isGoogleAccount ?? false;

  Future<void> initialize() async {
    _state = AuthState.loading;
    notifyListeners();

    await _authService.initialize();
    _user = _authService.currentUser;

    if (_user != null) {
      await _activateSession();
    } else {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  void completeRestore() {
    _authService.completeRestore().then((_) {
      final refreshed = _authService.currentUser;
      if (refreshed == null) {
        if (_user == null && _state == AuthState.unauthenticated) {
          notifyListeners();
        }
        return;
      }
      if (_user == null || refreshed.updatedAt.isAfter(_user!.updatedAt)) {
        _user = refreshed;
        if (_state == AuthState.unauthenticated) {
          _state = AuthState.authenticated;
          _activateSession();
        }
        notifyListeners();
      }
    });
  }

  Future<void> _activateSession() async {
    final owner = _db.getDataOwnerUid();
    if (owner != null && owner != _user!.id) {
      await _db.clearAll();
      await StepsService.getInstance().clearStepHistory();
    }
    await _db.setDataOwnerUid(_user!.id);

    _syncService.setUser(_user!.id, cloudEnabled: cloudSyncEnabled);
    if (cloudSyncEnabled) {
      _syncService.pullFromCloud();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.login(email: email, password: password);
      _state = AuthState.authenticated;
      await _activateSession();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    String? username,
  }) async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.register(
        email: email,
        password: password,
        displayName: displayName,
        username: username,
      );
      _state = AuthState.authenticated;
      await _activateSession();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.signInWithGoogle();
      _state = AuthState.authenticated;
      await _activateSession();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _syncService.clearUserData();
    _user = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    String? photoUrl,
  }) async {
    try {
      _user = await _authService.updateProfile(
        displayName: displayName,
        username: username,
        bio: bio,
        photoUrl: photoUrl,
      );
      _syncService.saveUserToFirestore(_user!.toJson());
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword({required String email}) async {
    try {
      await _authService.resetPassword(email: email);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      await _authService.deleteAccount();
      _user = null;
      _state = AuthState.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
