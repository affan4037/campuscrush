import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/storage_service.dart';
import '../../../services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../models/google_user.dart';

class GoogleAuthService extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  final ApiService _apiService;
  final StorageService _storageService;

  GoogleUser? _currentUser;
  String? _token;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;

  GoogleAuthService(this._apiService, this._storageService) {
    _firebaseAuth.authStateChanges().listen((User? user) {
      debugPrint(user != null
          ? '🔐 Auth: User signed in: ${user.email}'
          : '🔐 Auth: User signed out');
    });
  }

  GoogleUser? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Converts technical Firebase errors into user-friendly messages
  String _getUserFriendlyErrorMessage(dynamic error) {
    final String errorString = error.toString().toLowerCase();

    // Network related errors
    if (errorString.contains('network') ||
        errorString.contains('socketexception') ||
        errorString.contains('connection')) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }

    // Firebase configuration issues
    if (errorString.contains('firebase') && errorString.contains('configure')) {
      return 'Sign-in service is temporarily unavailable. Please try again later.';
    }

    // PlatformException handling
    if (errorString.contains('platformexception')) {
      if (errorString.contains('canceled') ||
          errorString.contains('cancelled')) {
        return 'Sign-in was canceled. Please try again.';
      }
      if (errorString.contains('network_error')) {
        return 'Network error. Please check your connection and try again.';
      }
      if (errorString.contains('web_context_canceled')) {
        return 'Sign-in window was closed. Please try again.';
      }
    }

    // Common Firebase Auth errors
    if (errorString.contains('credential') ||
        errorString.contains('auth/invalid-credential')) {
      return 'Your account credentials couldn\'t be verified. Please try again.';
    }

    if (errorString.contains('pigeon') ||
        errorString.contains('list<object?>') ||
        errorString.contains('subtype')) {
      return 'Sign-in service encountered a temporary issue. Please try again.';
    }

    // Default message for other errors
    return 'Something went wrong with sign-in. Please try again.';
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _setError(null);

    try {
      debugPrint('🔄 Starting Google Sign-In process');
      final prefs = await SharedPreferences.getInstance();
      final wasLoggedOut = prefs.getBool('user_logged_out') ?? false;
      final forceAccountPicker = prefs.getBool('force_account_picker') ?? false;

      if (forceAccountPicker) {
        await prefs.remove('force_account_picker');
      }

      GoogleSignInAccount? googleUser;

      if (wasLoggedOut || forceAccountPicker) {
        await _googleSignIn.disconnect();
        await _googleSignIn.signOut();

        final silentUser = await _googleSignIn.signInSilently();
        if (silentUser != null) {
          await _googleSignIn.disconnect();
          await _googleSignIn.signOut();
        }

        debugPrint('🔄 Showing Google account picker');
        googleUser = await _googleSignIn.signIn();

        if (googleUser != null && wasLoggedOut) {
          await prefs.setBool('user_logged_out', false);
        }
      } else {
        debugPrint('🔄 Using regular Google sign-in flow');
        googleUser = await _googleSignIn.signIn();
      }

      if (googleUser == null) {
        debugPrint('❌ Google Sign-In was canceled by user');
        _setError('Sign-in was canceled. Please try again when ready.');
        return false;
      }

      debugPrint('✅ Google user authenticated: ${googleUser.email}');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('🔄 Signing in with Firebase using Google credential');
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) {
        debugPrint('❌ Firebase user is null after authentication');
        _setError(
            'Unable to retrieve your account information. Please try again.');
        return false;
      }

      debugPrint('✅ Firebase user authenticated: ${user.email}');
      return await _processAuthenticatedUser(user);
    } catch (e) {
      debugPrint('❌ Google Auth error: $e');

      // Handle platform channel error
      if (e.toString().contains(
          "'List<Object?>' is not a subtype of type 'PigeonUserDetails?'")) {
        return await _handlePigeonUserDetailsError();
      }

      // If the error is invalid-credential or similar, force a full sign-out and prompt retry
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('credential') ||
          errorString.contains('auth/invalid-credential')) {
        debugPrint(
            '❌ Detected invalid credential, forcing full Google sign-out');
        await _googleSignIn.disconnect();
        await _googleSignIn.signOut();
        _setError(
            'Your account credentials couldn\'t be verified. Please try again. We have reset your Google sign-in, so please try again now.');
        return false;
      }

      _setError(_getUserFriendlyErrorMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Handles the specific PigeonUserDetails error that can occur in the Firebase plugin
  Future<bool> _handlePigeonUserDetailsError() async {
    debugPrint('🔄 Detected PigeonUserDetails error, trying to recover');

    // First try: Use existing Firebase user
    try {
      final User? user = _firebaseAuth.currentUser;
      if (user != null) {
        return await _processAuthenticatedUser(user,
            ignoreBackendErrors: true, isRefresh: true);
      }
    } catch (pigeonError) {
      debugPrint('❌ Failed to recover using current user: $pigeonError');
    }

    // Second try: Silent sign-in
    try {
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential =
            await _firebaseAuth.signInWithCredential(credential);
        final User? firebaseUser = userCredential.user;
        if (firebaseUser != null) {
          return await _processAuthenticatedUser(firebaseUser, isRefresh: true);
        }
      }
    } catch (silentError) {
      debugPrint('❌ Silent sign-in recovery failed: $silentError');
    }

    // All recovery attempts failed
    _setError('Sign-in failed. Please try again or restart the app.');
    return false;
  }

  Future<bool> _processAuthenticatedUser(User user,
      {bool ignoreBackendErrors = false, bool isRefresh = false}) async {
    final String? firebaseToken = await user.getIdToken();
    if (firebaseToken == null) {
      _setError('Failed to get authentication token');
      return false;
    }

    final success =
        await _authenticateWithBackend(firebaseToken, user, refresh: isRefresh);
    if (!success && !ignoreBackendErrors) {
      return false;
    }

    _currentUser = GoogleUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
      photoUrl: user.photoURL,
    );

    await _storageService.saveUserData(_currentUser!.toJson());

    // Clear the logged_out flag since we have successfully authenticated
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('user_logged_out', false);

    _isAuthenticated = true;
    notifyListeners();
    return true;
  }

  Future<bool> _authenticateWithBackend(String firebaseToken, User user,
      {bool refresh = false}) async {
    try {
      debugPrint('🔄 Authenticating with backend using Firebase token');
      const endpoint = '${AppConstants.apiPrefix}/auth/google-signin';

      final response = await _apiService.post<Map<String, dynamic>>(
        endpoint,
        data: {
          'firebase_token': firebaseToken,
          'email': user.email,
          'name': user.displayName,
          'photo_url': user.photoURL,
          'refresh': refresh,
        },
      );

      if (response.isSuccess && response.data != null) {
        final String accessToken = response.data!['access_token'];

        // Store token using the storage service (which now handles both secure storage and prefs)
        await _storageService.saveAuthToken(accessToken);
        debugPrint(
            '🟢 saveAuthToken called from GoogleAuthService with token: $accessToken');

        _token = accessToken;
        _apiService.setAuthToken(accessToken);

        debugPrint('✅ Successfully authenticated with backend');
        return true;
      } else {
        final statusCode = response.statusCode;
        String errorMessage;

        debugPrint(
            '❌ Backend authentication failed: ${response.error} (Status: $statusCode)');
        debugPrint('❌ Response data: ${response.data}');

        if (statusCode == 401 || statusCode == 403) {
          errorMessage =
              'Your account doesn\'t have access to this app. Please contact support.';
        } else if (statusCode == 404) {
          errorMessage =
              'Service temporarily unavailable. Please try again later.';
        } else if (statusCode == 500) {
          errorMessage = 'Our server is having issues. Please try again later.';
        } else {
          errorMessage = 'Unable to complete sign-in. Please try again.';
        }

        _setError(errorMessage);
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error during backend authentication: $e');
      _setError('Connection error. Please try again later.');
      return false;
    }
  }

  // Add a method to refresh the Firebase token when needed
  Future<String?> refreshFirebaseToken() async {
    try {
      if (_firebaseAuth.currentUser == null) {
        debugPrint('❌ No Firebase user available for token refresh');
        return null;
      }

      // Get a fresh token from Firebase
      final String? newToken =
          await _firebaseAuth.currentUser?.getIdToken(true);

      if (newToken != null && newToken.isNotEmpty) {
        debugPrint('🔄 Successfully refreshed Firebase token');

        // Re-authenticate with backend using new token
        if (await _processAuthenticatedUser(_firebaseAuth.currentUser!,
            isRefresh: true)) {
          return _token; // Return the backend JWT token, not the Firebase token
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error refreshing Firebase token: $e');
      return null;
    }
  }

  Future<bool> signOut() async {
    _setLoading(true);

    try {
      // More aggressively clear Google Sign-In state
      try {
        await _googleSignIn.disconnect();
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Error during Google sign out: $e');
        // Continue with logout even if Google sign out fails
      }

      // Clear Firebase auth
      await _firebaseAuth.signOut();

      _currentUser = null;
      _token = null;
      _isAuthenticated = false;

      await _storageService.deleteAuthToken();
      _apiService.clearAuthToken();

      // Set flag that user has explicitly logged out
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user_logged_out', true);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Sign out error: $e');
      _setError('Error during sign out: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> isSignedIn() async {
    final User? currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) return false;

    final String? token = await _storageService.getAuthToken();
    return token != null && token.isNotEmpty;
  }

  // Static method to get a fresh Firebase token - can be called from anywhere
  static Future<String?> getFreshFirebaseToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ No Firebase user found for token refresh');
        return null;
      }

      // Force token refresh with Firebase
      final freshToken = await user.getIdToken(true);
      debugPrint('🔄 Got fresh Firebase token');
      return freshToken;
    } catch (e) {
      debugPrint('❌ Error getting fresh Firebase token: $e');
      return null;
    }
  }
}
