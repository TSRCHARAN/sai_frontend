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
  final UserService _userService = UserService();

  Future<String> getUserId() => _userService.getUserId();

  Future<Map<String, dynamic>> sendMessage(String message, {String? sessionId}) async {
    final userId = await _userService.getUserId();
    final effectiveSessionId = sessionId ?? await _userService.getSessionId();

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/chat"),
        headers: {"Content-Type": "application/json"},
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
      print("Timezone fetch error: $e");
    }

    final request = http.Request('POST', Uri.parse("$baseUrl/chat_stream"));
    request.headers['Content-Type'] = 'application/json';
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
    request.headers['Content-Type'] = 'application/json';
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
      final response = await http.get(Uri.parse("$baseUrl/memories/$userId"));

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
      final response = await http.delete(Uri.parse("$baseUrl/memories/$id"));

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
        headers: {"Content-Type": "application/json"},
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
      final response = await http.get(Uri.parse("$baseUrl/profile/$userId"));

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
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(profile.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to update profile: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Network error: $e");
    }
  }
}
