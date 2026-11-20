import 'dart:convert';
import 'package:http/http.dart' as http;

class AgendaService {
  // Points directly to your Express API port
  static const String baseUrl = 'https://lucasace.com';

  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Server returned status ${response.statusCode}');
    }
  }

  static Future<dynamic> displayAppointments(String username) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/displayappointments'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'login': username}),
        )
        .timeout(const Duration(seconds: 10));
    return _handleResponse(response);
  }

  static Future<dynamic> createAppointment(
    String username,
    String apptName,
    String date,
    String startTime,
    String endTime,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/createappointment'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'login': username,
            'apptname': apptName,
            'date': date,
            'starttime': startTime,
            'endtime': endTime,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return _handleResponse(response);
  }

  static Future<dynamic> deleteAppointment(String username, String appointmentId) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/deleteappointment'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'login': username,
            'appointmentID': appointmentId,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return _handleResponse(response);
  }
}