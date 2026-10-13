import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _onboardingComplete = true;

  AuthState get state => _state;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get onboardingComplete => _onboardingComplete;

  bool get cloudSyncEnabled => _user?.isGoogleAccount ?? false;

  Future<void> initialize() async {
    _state = AuthState.loading;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    } catch (_) {}

    try {
      await _authService.initialize();
    } catch (e) {
      debugPrint('Auth init failed: $e');
    }

    _user = _authService.currentUser;

    if (_user != null) {
      try {
        await _activateSession();
      } catch (e) {
        debugPrint('Session activation failed: $e');
      }
      _state = AuthState.authenticated;
    } else {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  void completeRestore() {
    _authService.completeRestore().then((_) {
      if (_state != AuthState.unauthenticated) return;
      final refreshed = _authService.currentUser;
      if (refreshed == null) {
        notifyListeners();
        return;
      }
      if (_user == null || refreshed.updatedAt.isAfter(_user!.updatedAt)) {
        _user = refreshed;
        _state = AuthState.authenticated;
        unawaited(_activateSession());
        notifyListeners();
      }
    });
  }

  Future<void> _activateSession() async {
    final user = _user;
    if (user == null) return;

    final owner = _db.getDataOwnerUid();
    if (owner != null && owner != user.id) {
      await _db.clearAll();
      await StepsService.getInstance().clearStepHistory();
    }
    await _db.setDataOwnerUid(user.id);

    _syncService.setUser(user.id, cloudEnabled: cloudSyncEnabled);
    if (cloudSyncEnabled) {
      unawaited(_syncService.pullFromCloud());
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
    await _db.clearDataOwner();
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
