import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // Points to your Express backend port
  static const String baseUrl = 'https://lucasace.com';

  static dynamic _parseResponse(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid server response (Status ${response.statusCode})');
    }
  }

  static Future<dynamic> login(String username, String password) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'login': username.trim(),
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 10));

    return _parseResponse(response);
  }

  static Future<dynamic> register(
    String username,
    String password,
    String firstName,
    String lastName,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'login': username.trim(),
            'password': password,
            'firstname': firstName.trim(),
            'lastname': lastName.trim(),
          }),
        )
        .timeout(const Duration(seconds: 10));

    return _parseResponse(response);
  }
}