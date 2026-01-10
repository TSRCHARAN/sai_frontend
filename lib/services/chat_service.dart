import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'user_service.dart';
import '../models/memory.dart';
import '../models/user_profile.dart';

class ChatService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS/Web
  // For physical device, use your machine's local IP (e.g., 192.168.x.x)
  static String get baseUrl => dotenv.env['API_URL'] ?? "http://10.0.2.2:8000"; 
  static String get apiKey => dotenv.env['API_SECRET'] ?? "";
  
  final UserService _userService = UserService();
  
  Future<Map<String, String>> get _headers async {
    final token = await _userService.getAuthToken();
    return {
      "Content-Type": "application/json",
      "X-API-Key": apiKey,
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  Future<String> getUserId() => _userService.getUserId();

  Future<Map<String, dynamic>> sendMessage(String message, {String? sessionId}) async {
    final userId = await _userService.getUserId();
    final effectiveSessionId = sessionId ?? await _userService.getSessionId();

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/chat"),
        headers: await _headers,
        body: jsonEncode({
          "user_id": userId,
          "session_id": effectiveSessionId,
          "message": message,
        }),
      );


      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to send message: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Network error: $e");
    }
  }

  Stream<String> sendMessageStream(String message, {String? sessionId}) async* {
    final userId = await _userService.getUserId();
    final effectiveSessionId = sessionId ?? await _userService.getSessionId();
    
    String timezoneName = "UTC";
    try {
      final dynamic timezoneObj = await FlutterTimezone.getLocalTimezone();
      // Handle both String (newer versions) and Object (older/custom versions)
      if (timezoneObj is String) {
        timezoneName = timezoneObj;
      } else if (timezoneObj != null) {
        // Assume it's the TimezoneInfo object with .identifier
        timezoneName = timezoneObj.identifier;
      }
    } catch (e) {
      // debugPrint("Timezone fetch error: $e");
    }

    final request = http.Request('POST', Uri.parse("$baseUrl/chat_stream"));
    request.headers.addAll(await _headers);
    request.body = jsonEncode({
      "user_id": userId,
      "session_id": effectiveSessionId,
      "message": message,
      "timezone": timezoneName,
    });

    try {
      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode == 200) {
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          yield chunk;
        }
      } else {
        yield "Error: ${response.statusCode}";
      }
      client.close();
    } catch (e) {
      yield "Network error: $e";
    }
  }

  Stream<String> getWelcomeStream({String? sessionId}) async* {
    final userId = await _userService.getUserId();
    final effectiveSessionId = sessionId ?? await _userService.getSessionId();

    final request = http.Request('POST', Uri.parse("$baseUrl/welcome_stream"));
    request.headers.addAll(await _headers);
    request.body = jsonEncode({
      "user_id": userId,
      "session_id": effectiveSessionId,
      "message": "INIT_WELCOME",
    });

    try {
      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode == 200) {
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          yield chunk;
        }
      } else {
        yield "Error: ${response.statusCode}";
      }
      client.close();
    } catch (e) {
      yield "Network error: $e";
    }
  }

  Future<List<Memory>> fetchMemories() async {
    final userId = await _userService.getUserId();
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/memories/$userId"),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> memoriesJson = data['memories'];
        return memoriesJson.map((json) => Memory.fromJson(json)).toList();
      } else {
        throw Exception("Failed to load memories: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Network error: $e");
    }
  }

  Future<void> deleteMemory(int id) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/memories/$id"),
        headers: await _headers,
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to delete memory: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Network error: $e");
    }
  }

  Future<void> updateMemory(int id, String content) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/memories/$id"),
        headers: await _headers,
        body: jsonEncode({"content": content}),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to update memory: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Network error: $e");
    }
  }

  Future<UserProfile> fetchProfile() async {
    final userId = await _userService.getUserId();
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/profile/$userId"),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserProfile.fromJson(data['profile']);
      } else {
        throw Exception("Failed to load profile: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Network error: $e");
    }
  }

  Future<void> updateProfile(UserProfile profile) async {
    final userId = await _userService.getUserId();
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/profile/$userId"),
        headers: await _headers,
        body: jsonEncode(profile.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to update profile: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Network error: $e");
    }
  }

  Future<void> logoutBackend(String sessionId) async {
    final userId = await _userService.getUserId();
    try {
      await http.post(
        Uri.parse("$baseUrl/auth/logout"),
        headers: await _headers,
        body: jsonEncode({
          "user_id": userId,
          "session_id": sessionId,
        }),
      );
    } catch (e) {
      // Fail silently if network is down during logout
      print("Logout backend warning: $e");
    }
  }

  Future<String> triggerTestNotification() async {
    final userId = await _userService.getUserId();
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/test/notification"),
        headers: await _headers,
        body: jsonEncode({
          "user_id": userId,
        }),
      );
      
      if (response.statusCode == 200) {
        return "Notification Sent! Check Status Bar.";
      } else {
        return "Failed: ${response.body}";
      }
    } catch (e) {
      return "Error: $e";
    }
  }

  Future<void> deleteAccount(String sessionId) async {
    final userId = await _userService.getUserId();
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/auth/account"),
        headers: await _headers,
        body: jsonEncode({
          "user_id": userId,
          "session_id": sessionId,
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception("Delete failed: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Could not delete account: $e");
    }
  }

  Future<Map<String, dynamic>> fetchPrivacyPolicy() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/privacy-policy"),
      );

      if (response.statusCode == 200) {
        // Return UTF-8 decoded body to support special chars
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        return {};
      }
    } catch (e) {
      return {};
    }
  }
}
