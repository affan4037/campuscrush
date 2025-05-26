import 'package:flutter/material.dart';

import '../services/google_auth_service.dart';
import '../models/google_user.dart';

class GoogleAuthProvider extends ChangeNotifier {
  final GoogleAuthService _googleAuthService;

  GoogleAuthProvider({required GoogleAuthService googleAuthService})
      : _googleAuthService = googleAuthService;

  // Forwarded getters from the service
  GoogleUser? get currentUser => _googleAuthService.currentUser;
  bool get isAuthenticated => _googleAuthService.isAuthenticated;
  bool get isLoading => _googleAuthService.isLoading;
  String? get error => _googleAuthService.error;

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    return await _googleAuthService.signInWithGoogle();
  }

  // Sign out
  Future<bool> signOut() async {
    return await _googleAuthService.signOut();
  }

  // Check if user is signed in
  Future<bool> isSignedIn() async {
    return await _googleAuthService.isSignedIn();
  }
}
