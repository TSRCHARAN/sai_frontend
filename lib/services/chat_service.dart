import 'dart:convert';
import 'package:http/http.dart' as http;
import 'user_service.dart';

class ChatService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS/Web
  // For physical device, use your machine's local IP (e.g., 192.168.x.x)
  static const String baseUrl = "http://192.168.0.1:8000"; 
  final UserService _userService = UserService();

  Future<Map<String, dynamic>> sendMessage(String message) async {
    final userId = await _userService.getUserId();
    final sessionId = await _userService.getSessionId();

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "session_id": sessionId,
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

  Stream<String> sendMessageStream(String message) async* {
    final userId = await _userService.getUserId();
    final sessionId = await _userService.getSessionId();

    final request = http.Request('POST', Uri.parse("$baseUrl/chat_stream"));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      "user_id": userId,
      "session_id": sessionId,
      "message": message,
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

  Stream<String> getWelcomeStream() async* {
    final userId = await _userService.getUserId();
    final sessionId = await _userService.getSessionId();

    final request = http.Request('POST', Uri.parse("$baseUrl/welcome_stream"));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      "user_id": userId,
      "session_id": sessionId,
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
}
