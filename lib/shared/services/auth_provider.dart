// lib/shared/services/auth_provider.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import 'auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, locked }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  AppUser? _user;
  AuthStatus _status = AuthStatus.initial;
  String _lockoutMessage = '';

  AppUser? get user => _user;
  AuthStatus get status => _status;
  String get lockoutMessage => _lockoutMessage;

  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLockedOut => _status == AuthStatus.locked;
  bool get isAdmin => _user?.role == 'admin';
  bool get isGuard => _user?.role == 'guard';

  AuthProvider() {
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();
    } else {
      // Background refresh won't kill active screen states anymore
      await refreshUser(isInitialLoad: _user == null);
    }
  }

  void setUser(AppUser appUser) {
    _user = appUser;
    _status = appUser.isActive ? AuthStatus.authenticated : AuthStatus.locked;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    _status = AuthStatus.loading;
    notifyListeners();
    try {
      final AppUser userProfile = await _authService.login(email, password);
      if (!userProfile.isActive) {
        _lockoutMessage = "Account deactivated.";
        _status = AuthStatus.locked;
        await _authService.signOut(userProfile.buildingId, userProfile.name);
        notifyListeners();
        return _lockoutMessage;
      }
      _user = userProfile;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return null;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return e.toString();
    }
  }

  /// ✅ FIXED: Defends the active local user cache layer against background stream connection drops
  Future<void> refreshUser({bool isInitialLoad = false}) async {
    if (isInitialLoad) {
      _status = AuthStatus.loading;
      notifyListeners();
    }

    try {
      final updatedUser = await _authService.getCurrentAppUser();
      if (updatedUser != null) {
        _user = updatedUser;
        _status = updatedUser.isActive ? AuthStatus.authenticated : AuthStatus.locked;
      }
    } catch (e) {
      debugPrint("⚠️ Background user refresh failed: $e");
      // ✅ CRITICAL: If we already have a user memory instance, don't wipe it out because of a network hiccup
      if (_user == null) {
        _status = AuthStatus.unauthenticated;
      }
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    final String bId = _user?.buildingId ?? 'GLOBAL_SYSTEM';
    final String uName = _user?.name ?? 'Unknown User';

    await _authService.signOut(bId, uName);
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}