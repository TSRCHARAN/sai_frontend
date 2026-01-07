import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_profile.dart';
import 'user_service.dart';

class ProfileService {
  static String get baseUrl => dotenv.env['API_URL'] ?? "http://10.0.2.2:8000";
  final UserService _userService = UserService();

  Future<UserProfile?> fetchUserProfile() async {
    final userId = await _userService.getUserId();
    try {
      final response = await http.get(Uri.parse("$baseUrl/profile/$userId"));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['profile'] != null) {
          return UserProfile.fromJson(data['profile']);
        }
        return null; // Empty profile
      } else {
        throw Exception("Failed to load profile: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Network error fetching profile: $e");
    }
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    final userId = await _userService.getUserId();
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/profile/$userId"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(profile.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to update profile: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Network error updating profile: $e");
    }
  }
}
