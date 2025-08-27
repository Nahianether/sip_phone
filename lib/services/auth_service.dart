import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../models/auth_response_model.dart';

class AuthService {
  static const String _authBoxName = 'auth_box';
  static const String _authDataKey = 'auth_data';
  static const String _isLoggedInKey = 'is_logged_in';
  
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._internal();
  AuthService._internal();

  Box<dynamic>? _authBox;
  AuthResponseModel? _currentUser;

  /// Initialize Hive box for authentication
  Future<void> initHive() async {
    try {
      _authBox = await Hive.openBox(_authBoxName);
      debugPrint('AuthService: Hive box initialized');
      
      // Load cached user data on initialization
      await _loadCachedUser();
    } catch (e) {
      debugPrint('AuthService: Error initializing Hive: $e');
    }
  }

  /// Load cached user data from Hive
  Future<void> _loadCachedUser() async {
    try {
      final authData = _authBox?.get(_authDataKey);
      if (authData != null) {
        _currentUser = authData as AuthResponseModel;
        debugPrint('AuthService: Loaded cached user: ${_currentUser?.displayName}');
      }
    } catch (e) {
      debugPrint('AuthService: Error loading cached user: $e');
    }
  }

  /// Login with email and password
  Future<AuthResult> login({
    required String email, 
    required String password,
  }) async {
    try {
      debugPrint('AuthService: Attempting login for $email');

      var headers = {
        'Content-Type': 'application/json',
      };

      var request = http.Request(
        'POST', 
        Uri.parse('https://arl.peopledesk.io/api/AuthApps/Login')
      );

      request.body = json.encode({
        "strLoginId": email.trim(),
        "strPassword": password,
        "intUrlId": 0,
        "strUrl": "https://arl.peopledesk.io",
        "intAccountId": 1,
      });

      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        debugPrint('AuthService: Login successful');

        // Parse response to AuthResponseModel
        final Map<String, dynamic> jsonData = json.decode(responseBody);
        final authResponse = AuthResponseModel.fromJson(jsonData);

        // Save to Hive
        await _saveAuthData(authResponse);
        
        return AuthResult.success(authResponse);
      } else {
        final errorBody = await response.stream.bytesToString();
        debugPrint('AuthService: Login failed - ${response.statusCode}: $errorBody');
        return AuthResult.failure('Login failed: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('AuthService: Login error: $e');
      return AuthResult.failure('Network error: ${e.toString()}');
    }
  }

  /// Save authentication data to Hive
  Future<void> _saveAuthData(AuthResponseModel authResponse) async {
    try {
      _currentUser = authResponse;
      await _authBox?.put(_authDataKey, authResponse);
      await _authBox?.put(_isLoggedInKey, true);
      debugPrint('AuthService: User data saved to Hive');
    } catch (e) {
      debugPrint('AuthService: Error saving auth data: $e');
    }
  }

  /// Get current authenticated user
  AuthResponseModel? get currentUser => _currentUser;

  /// Check if user is logged in
  bool get isLoggedIn {
    try {
      final isLoggedIn = _authBox?.get(_isLoggedInKey, defaultValue: false) ?? false;
      final hasValidUser = _currentUser != null && _currentUser!.isUserLoggedIn;
      return isLoggedIn && hasValidUser;
    } catch (e) {
      debugPrint('AuthService: Error checking login status: $e');
      return false;
    }
  }

  /// Get user token for API requests
  String? get userToken => _currentUser?.userToken;

  /// Get user display name
  String get userDisplayName => _currentUser?.displayName ?? 'Unknown User';

  /// Get user department
  String get userDepartment => _currentUser?.department ?? 'Unknown Department';

  /// Get user designation
  String get userDesignation => _currentUser?.designation ?? 'Unknown Designation';

  /// Logout user
  Future<void> logout() async {
    try {
      _currentUser = null;
      await _authBox?.delete(_authDataKey);
      await _authBox?.put(_isLoggedInKey, false);
      debugPrint('AuthService: User logged out');
    } catch (e) {
      debugPrint('AuthService: Error during logout: $e');
    }
  }

  /// Refresh user token (for future implementation)
  Future<AuthResult> refreshToken() async {
    try {
      final refreshToken = _currentUser?.refreshToken;
      if (refreshToken == null) {
        return AuthResult.failure('No refresh token available');
      }

      // TODO: Implement token refresh API call
      // For now, return current user
      return AuthResult.success(_currentUser!);
    } catch (e) {
      debugPrint('AuthService: Error refreshing token: $e');
      return AuthResult.failure('Token refresh failed: ${e.toString()}');
    }
  }

  /// Clear all authentication data (for debugging/testing)
  Future<void> clearAuthData() async {
    try {
      await _authBox?.clear();
      _currentUser = null;
      debugPrint('AuthService: All auth data cleared');
    } catch (e) {
      debugPrint('AuthService: Error clearing auth data: $e');
    }
  }

  /// Close Hive box when app is disposed
  Future<void> dispose() async {
    try {
      await _authBox?.close();
      debugPrint('AuthService: Hive box closed');
    } catch (e) {
      debugPrint('AuthService: Error closing Hive box: $e');
    }
  }
}

/// Authentication result wrapper
class AuthResult {
  final bool isSuccess;
  final AuthResponseModel? user;
  final String? error;

  AuthResult._({
    required this.isSuccess,
    this.user,
    this.error,
  });

  factory AuthResult.success(AuthResponseModel user) {
    return AuthResult._(isSuccess: true, user: user);
  }

  factory AuthResult.failure(String error) {
    return AuthResult._(isSuccess: false, error: error);
  }
}