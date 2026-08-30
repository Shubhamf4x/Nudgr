import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/user_model.dart';
import '../utils/validators.dart';

class AuthService {
  static AuthService? _instance;
  static SharedPreferences? _prefs;
  static final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserModel? _currentUser;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  static const String _authVersionKey = 'auth_version';
  static const String _currentAuthVersion = '2.0';

  AuthService._();

  static AuthService getInstance() {
    _instance ??= AuthService._();
    return _instance!;
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    final savedVersion = _prefs!.getString(_authVersionKey);
    if (savedVersion != _currentAuthVersion) {
      await _prefs!.remove('current_user');
      await _prefs!.remove('registered_users');
      await _prefs!.setString(_authVersionKey, _currentAuthVersion);
    }

    _loadCurrentUser();
  }

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  CollectionReference get _usernamesRef => _firestore.collection('usernames');
  CollectionReference get _usersRef => _firestore.collection('users');

  void _loadCurrentUser() {
    try {
      final jsonString = _prefs!.getString('current_user');
      if (jsonString != null && jsonString.isNotEmpty) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        _currentUser = UserModel.fromJson(json);
      }
    } catch (e) {
      _currentUser = null;
    }
  }

  bool _isEmail(String input) {
    return input.contains('@') && input.contains('.');
  }

  /// Detects how the Firebase user is authenticated. Google accounts get
  /// cloud sync; email/password accounts are local-only.
  bool _detectGoogleAccount(fb.User fbUser) {
    if (fbUser.isAnonymous) return false;
    return fbUser.providerData.any((info) => info.providerId == 'google.com');
  }

  // ── Login ──────────────────────────────────────────────────────────

  Future<UserModel> login({required String email, required String password}) async {
    final input = email.trim().toLowerCase();

    // Step 1: Resolve username → email via Firestore (with short timeout)
    String resolvedEmail = input;
    if (!_isEmail(input)) {
      try {
        resolvedEmail = await _resolveUsernameToEmail(input);
      } on TimeoutException {
        throw Exception('Network timeout. Please check your connection.');
      } catch (e) {
        throw Exception('No account found with this username');
      }
    }

    // Step 2: Firebase Auth sign-in (with timeout)
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: resolvedEmail,
        password: password,
      ).timeout(const Duration(seconds: 15));
      final fbUser = userCredential.user;
      if (fbUser == null) throw Exception('Firebase sign in failed');
      return _handleFirebaseLogin(fbUser, resolvedEmail);
    } on TimeoutException {
      throw Exception('Network timeout. Please check your connection and try again.');
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_firebaseAuthErrorMessage(e));
    } catch (e) {
      if (e.toString().contains('timeout') || e.toString().contains('Timeout')) {
        throw Exception('Network timeout. Please check your connection and try again.');
      }
      throw Exception('Login failed. Please try again.');
    }
  }

  UserModel _handleFirebaseLogin(fb.User fbUser, String email) {
    final users = _getRegisteredUsers();
    int existingIndex = -1;
    for (int i = 0; i < users.length; i++) {
      final storedUid = users[i]['id'] as String? ?? '';
      if (storedUid == fbUser.uid) {
        existingIndex = i;
        break;
      }
    }

    Map<String, dynamic> userData;

    if (existingIndex >= 0) {
      userData = Map<String, dynamic>.from(users[existingIndex]);
      userData['isOnline'] = true;
      userData['lastSeen'] = DateTime.now().toIso8601String();
      userData['email'] = fbUser.email ?? email;
      userData['isGoogleAccount'] = _detectGoogleAccount(fbUser);
      users[existingIndex] = userData;
      _saveRegisteredUsers(users);
    } else {
      final now = DateTime.now().toIso8601String();
      final displayName = fbUser.displayName ?? email.split('@').first;
      final username = InputValidators.sanitizeUsername(displayName);
      userData = <String, dynamic>{
        'id': fbUser.uid,
        'email': fbUser.email ?? email,
        'displayName': displayName,
        'username': username,
        'photoUrl': fbUser.photoURL,
        'bio': null,
        'isOnline': true,
        'lastSeen': now,
        'createdAt': now,
        'updatedAt': now,
        'preferences': <String, dynamic>{},
        'statistics': <String, dynamic>{
          'totalTasks': 0,
          'completedTasks': 0,
          'totalNotes': 0,
          'focusMinutes': 0,
        },
        'isGoogleAccount': _detectGoogleAccount(fbUser),
      };
      users.add(userData);
      _saveRegisteredUsers(users);
      _syncUserToFirestore(userData);
    }

    final userModel = UserModel.fromJson(userData);
    _currentUser = userModel;
    _prefs!.setString('current_user', jsonEncode(userModel.toJson()));
    return userModel;
  }

  Future<String> _resolveUsernameToEmail(String username) async {
    final normalizedUsername = InputValidators.sanitizeUsername(username);
    final doc = await _usernamesRef.doc(normalizedUsername).get()
        .timeout(const Duration(seconds: 3));
    if (!doc.exists) {
      throw Exception('No account found with this username');
    }
    final data = doc.data() as Map<String, dynamic>;
    return data['email'] as String;
  }

  // ── Register ───────────────────────────────────────────────────────

  Future<UserModel> register({
    required String email,
    required String password,
    required String displayName,
    String? username,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    // Sanitise the username BEFORE any uniqueness check or Firestore write so
    // the `usernames` mapping doc ID is always a safe, normalized value.
    final finalUsername = InputValidators.sanitizeUsername(
      (username != null && username.isNotEmpty)
          ? username
          : displayName,
    );

    // Check username uniqueness (short timeout — skip if Firestore unavailable)
    try {
      final usernameDoc = await _usernamesRef.doc(finalUsername).get()
          .timeout(const Duration(seconds: 3));
      if (usernameDoc.exists) {
        throw Exception('Username already taken');
      }
    } catch (e) {
      if (e.toString().contains('Username already taken')) rethrow;
    }

    // Create Firebase Auth account (with timeout)
    fb.User? fbUser;
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      ).timeout(const Duration(seconds: 15));
      fbUser = userCredential.user;
    } on TimeoutException {
      throw Exception('Network timeout. Please check your connection and try again.');
    } on fb.FirebaseAuthException catch (e) {
      throw Exception(_firebaseAuthErrorMessage(e));
    } catch (e) {
      if (e.toString().contains('timeout') || e.toString().contains('Timeout')) {
        throw Exception('Network timeout. Please check your connection and try again.');
      }
      throw Exception('Registration failed. Please try again.');
    }
    if (fbUser == null) throw Exception('Firebase registration failed');

    // Build user data
    final now = DateTime.now().toIso8601String();
    final userData = <String, dynamic>{
      'id': fbUser.uid,
      'email': normalizedEmail,
      'displayName': displayName,
      'username': finalUsername,
      'photoUrl': fbUser.photoURL,
      'bio': null,
      'isOnline': true,
      'lastSeen': now,
      'createdAt': now,
      'updatedAt': now,
      'preferences': <String, dynamic>{},
      'statistics': <String, dynamic>{
        'totalTasks': 0,
        'completedTasks': 0,
        'totalNotes': 0,
        'focusMinutes': 0,
      },
      // Email/password accounts are local-only (no cloud sync).
      'isGoogleAccount': false,
    };

    // Save locally FIRST (instant)
    final users = _getRegisteredUsers();
    users.add(userData);
    _saveRegisteredUsers(users);

    final userModel = UserModel.fromJson(userData);
    _currentUser = userModel;
    _prefs!.setString('current_user', jsonEncode(userModel.toJson()));

    // Firestore writes (non-blocking, fire-and-forget)
    _syncUsernameMapping(finalUsername, normalizedEmail, fbUser.uid);
    _syncUserToFirestore(userData);

    return userModel;
  }

  // ── Google Sign-In ─────────────────────────────────────────────────

  Future<UserModel> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign in was cancelled');
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    fb.User? fbUser;
    try {
      final userCredential = await _firebaseAuth.signInWithCredential(credential)
          .timeout(const Duration(seconds: 15));
      fbUser = userCredential.user;
    } on TimeoutException {
      throw Exception('Network timeout. Please check your connection and try again.');
    } catch (e) {
      if (e.toString().contains('timeout') || e.toString().contains('Timeout')) {
        throw Exception('Network timeout. Please check your connection and try again.');
      }
      throw Exception('Google sign in failed. Please try again.');
    }
    if (fbUser == null) throw Exception('Firebase sign in failed');

    final email = fbUser.email ?? googleUser.email;
    final displayName = fbUser.displayName ?? googleUser.displayName ?? email.split('@').first;
    final photoUrl = fbUser.photoURL ?? googleUser.photoUrl;
    final normalizedEmail = email.toLowerCase();

    final users = _getRegisteredUsers();
    int existingIndex = -1;
    for (int i = 0; i < users.length; i++) {
      final storedUid = users[i]['id'] as String? ?? '';
      if (storedUid == fbUser.uid) {
        existingIndex = i;
        break;
      }
    }

    Map<String, dynamic> userData;

    if (existingIndex >= 0) {
      userData = Map<String, dynamic>.from(users[existingIndex]);
      userData['isOnline'] = true;
      userData['lastSeen'] = DateTime.now().toIso8601String();
      if (photoUrl != null) userData['photoUrl'] = photoUrl;
      if (displayName.isNotEmpty) userData['displayName'] = displayName;
      userData['isGoogleAccount'] = true;
      users[existingIndex] = userData;
      _saveRegisteredUsers(users);
    } else {
      final now = DateTime.now().toIso8601String();
      final username = InputValidators.sanitizeUsername(displayName);
      userData = <String, dynamic>{
        'id': fbUser.uid,
        'email': normalizedEmail,
        'displayName': displayName,
        'username': username,
        'photoUrl': photoUrl,
        'bio': null,
        'isOnline': true,
        'lastSeen': now,
        'createdAt': now,
        'updatedAt': now,
        'preferences': <String, dynamic>{},
        'statistics': <String, dynamic>{
          'totalTasks': 0,
          'completedTasks': 0,
          'totalNotes': 0,
          'focusMinutes': 0,
        },
        // Google accounts get full cloud sync.
        'isGoogleAccount': true,
      };
      users.add(userData);
      _saveRegisteredUsers(users);
      _syncUserToFirestore(userData);
    }

    final userModel = UserModel.fromJson(userData);
    _currentUser = userModel;
    _prefs!.setString('current_user', jsonEncode(userModel.toJson()));
    return userModel;
  }

  // ── Firestore Helpers (non-blocking) ───────────────────────────────

  void _syncUserToFirestore(Map<String, dynamic> userData) {
    try {
      _usersRef.doc(userData['id'] as String).set(userData, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Restores profile data pulled from the cloud (used when a Google user
  /// logs in on a fresh device/reinstall). The cloud copy only wins when it
  /// is strictly newer than the local one, so offline edits are never lost.
  void mergeCloudProfile(Map<String, dynamic> cloudData) {
    if (_currentUser == null) return;

    final cloudUpdated =
        DateTime.tryParse(cloudData['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
    if (!cloudUpdated.isAfter(_currentUser!.updatedAt)) return;

    final merged = _currentUser!.copyWith(
      displayName:
          (cloudData['displayName'] as String?) ?? _currentUser!.displayName,
      username: (cloudData['username'] as String?) ?? _currentUser!.username,
      photoUrl: (cloudData['photoUrl'] as String?) ?? _currentUser!.photoUrl,
      bio: (cloudData['bio'] as String?) ?? _currentUser!.bio,
      statistics: (cloudData['statistics'] as Map<String, dynamic>?) ??
          _currentUser!.statistics,
      updatedAt: cloudUpdated,
    );

    _currentUser = merged;
    _prefs!.setString('current_user', jsonEncode(merged.toJson()));

    final users = _getRegisteredUsers();
    final index = users.indexWhere((u) => u['id'] == merged.id);
    if (index >= 0) {
      users[index] = Map<String, dynamic>.from(users[index])..addAll(merged.toJson());
      _saveRegisteredUsers(users);
    }
  }

  void _syncUsernameMapping(String username, String email, String uid) {
    try {
      _usernamesRef.doc(username).set({
        'email': email,
        'uid': uid,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // ── Profile ────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (_) {}
    _currentUser = null;
    await _prefs!.remove('current_user');
  }

  Future<UserModel> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    String? photoUrl,
  }) async {
    if (_currentUser == null) throw Exception('Not authenticated');

    if (username != null && username.isNotEmpty) {
      try {
        final normalizedUsername = username.toLowerCase();
        final existingDoc = await _usernamesRef.doc(normalizedUsername).get()
            .timeout(const Duration(seconds: 3));
        if (existingDoc.exists) {
          final data = existingDoc.data() as Map<String, dynamic>;
          if (data['uid'] != _currentUser!.id) {
            throw Exception('Username already taken');
          }
        }
      } catch (e) {
        if (e.toString().contains('Username already taken')) rethrow;
      }
    }

    final updated = _currentUser!.copyWith(
      displayName: displayName,
      username: username,
      bio: bio,
      photoUrl: photoUrl,
      updatedAt: DateTime.now(),
    );

    _currentUser = updated;
    await _prefs!.setString('current_user', jsonEncode(updated.toJson()));

    _syncUserToFirestore(updated.toJson());

    final users = _getRegisteredUsers();
    final index = users.indexWhere((u) => u['id'] == updated.id);
    if (index >= 0) {
      users[index] = Map<String, dynamic>.from(users[index])..addAll(updated.toJson());
      await _saveRegisteredUsers(users);
    }

    return updated;
  }

  Future<UserModel> updateStatistics(Map<String, dynamic> stats) async {
    if (_currentUser == null) throw Exception('Not authenticated');

    final currentStats = Map<String, dynamic>.from(_currentUser!.statistics);
    stats.forEach((key, value) {
      if (value is int && currentStats[key] is int) {
        currentStats[key] = (currentStats[key] as int) + value;
      } else {
        currentStats[key] = value;
      }
    });

    final updated = _currentUser!.copyWith(
      statistics: currentStats,
      updatedAt: DateTime.now(),
    );

    _currentUser = updated;
    await _prefs!.setString('current_user', jsonEncode(updated.toJson()));

    try {
      _usersRef.doc(updated.id).set(
        {'statistics': currentStats, 'updatedAt': updated.updatedAt.toIso8601String()},
        SetOptions(merge: true),
      );
    } catch (_) {}

    final users = _getRegisteredUsers();
    final index = users.indexWhere((u) => u['id'] == updated.id);
    if (index >= 0) {
      users[index] = Map<String, dynamic>.from(users[index])..addAll(updated.toJson());
      await _saveRegisteredUsers(users);
    }

    return updated;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) throw Exception('Not authenticated');

    final fbUser = _firebaseAuth.currentUser;
    if (fbUser == null || fbUser.email == null) throw Exception('Not authenticated with Firebase');

    final credential = fb.EmailAuthProvider.credential(
      email: fbUser.email!,
      password: currentPassword,
    );
    await fbUser.reauthenticateWithCredential(credential);
    await fbUser.updatePassword(newPassword);
  }

  Future<void> deleteAccount() async {
    if (_currentUser == null) throw Exception('Not authenticated');

    final users = _getRegisteredUsers();
    users.removeWhere((u) => u['id'] == _currentUser!.id);
    await _saveRegisteredUsers(users);

    try {
      _usersRef.doc(_currentUser!.id).delete();
    } catch (_) {}

    _currentUser = null;
    await _prefs!.remove('current_user');
  }

  Future<void> resetPassword({required String email}) async {
    final normalizedEmail = email.trim().toLowerCase();
    await _firebaseAuth.sendPasswordResetEmail(email: normalizedEmail);
  }

  // ── Helpers ────────────────────────────────────────────────────────

  String _firebaseAuthErrorMessage(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email. Please register first.';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'email-already-in-use':
        return 'An account with this email already exists';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email address';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return e.message ?? 'Authentication failed';
    }
  }

  List<Map<String, dynamic>> _getRegisteredUsers() {
    try {
      final jsonString = _prefs!.getString('registered_users');
      if (jsonString == null || jsonString.isEmpty) return [];
      final decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveRegisteredUsers(List<Map<String, dynamic>> users) async {
    await _prefs!.setString('registered_users', jsonEncode(users));
  }

  Future<void> clearAllData() async {
    _currentUser = null;
    await _prefs!.remove('current_user');
    await _prefs!.remove('registered_users');
  }
}
