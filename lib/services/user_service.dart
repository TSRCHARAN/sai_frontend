import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserService {
  static const String _userIdKey = 'user_id';
  static const String _sessionIdKey = 'session_id';
  
  // Google Sign In Instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(
     serverClientId: dotenv.env['GOOGLE_CLIENT_ID'],
   );

  Stream<GoogleSignInAccount?> get onAuthStateChanged => _googleSignIn.onCurrentUserChanged;
  
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Returns the current User ID.
  /// 
  /// Priority:
  /// 1. Google Account ID (if signed in) -> Stable across devices.
  /// 2. Local UUID (if guest) -> Stable on this device only.
  Future<String> getUserId() async {
    // 1. Check if Google User is already cached/signed in silenty
    var googleUser = _googleSignIn.currentUser;
    if (googleUser == null) {
      // Try to recover session silently
      try {
        googleUser = await _googleSignIn.signInSilently();
      } catch (e) {
        // print("Silent sign-in failed: $e");
      }
    }

    if (googleUser != null) {
      return googleUser.id;
    }

    // 2. Fallback to Local Storage (Guest Mode)
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString(_userIdKey);

    if (userId == null) {
      userId = const Uuid().v4();
      await prefs.setString(_userIdKey, userId);
    }
    return userId;
  }
  
  /// Initiates the Google Sign-In flow.
  /// Returns True if successful.
  Future<bool> signInWithGoogle() async {
    // 1. Capture current ID (Guest)
    final prefs = await SharedPreferences.getInstance();
    final guestId = prefs.getString(_userIdKey);

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;
      
      final googleId = account.id;

      // 3. Pro Architect Move: Merge Guest Data if exists and different
      if (guestId != null && guestId != googleId) {
          try {
             await _mergeAccounts(guestId, googleId);
             debugPrint("Merged guest $guestId into google $googleId");
          } catch(e) {
             debugPrint("Merge failed (non-fatal): $e");
          }
          
          // 4. Clear Guest ID to prevent "falling back" to it later
          // We are now fully Google ID.
          await prefs.remove(_userIdKey); 
      }
      return true;
    } catch (e) {
      print("Google Sign In Error: $e");
      return false;
    }
  }

  /// Signs out of Google and reverts to Guest Mode (Fresh ID).
  /// Also rotates the session ID to prevent data leakage between users.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    
    final prefs = await SharedPreferences.getInstance();
    // Clear the stored Guest ID so we generate a fresh one
    await prefs.remove(_userIdKey);

    // Architect's Touch: Rotate Session ID immediately on logout
    await resetSession();
  }
  
  Future<void> _mergeAccounts(String guestId, String googleId) async {
    final String baseUrl = dotenv.env['API_URL'] ?? "http://10.0.2.2:8000";
    final url = Uri.parse("$baseUrl/auth/merge");
    
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "source_user_id": guestId,
        "target_user_id": googleId
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception("Failed to merge accounts: ${response.body}");
    }
  }
  
  /// Gets the ID Token (JWT) to send to the backend for verification.
  Future<String?> getAuthToken() async {
    final user = _googleSignIn.currentUser;
    if (user == null) return null;
    
    final auth = await user.authentication;
    return auth.idToken;
  }

  Future<String> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    String? sessionId = prefs.getString(_sessionIdKey);

    if (sessionId == null) {
      sessionId = const Uuid().v4();
      await prefs.setString(_sessionIdKey, sessionId);
    }
    return sessionId;
  }

  Future<void> resetSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionIdKey, const Uuid().v4());
  }
}
