import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _backendUrl = 'http://192.168.43.192:3002';
  static const String _cameraUrl = "http://192.168.43.167";
  static const String _doorLockUrl = "http://192.168.43.152";
  static const Duration _timeout = Duration(seconds: 10);

  // Metodă pentru autentificare
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(_timeout);

      final responseData = _handleResponse(response);
      return {
        'success': response.statusCode == 200 && (responseData['success'] ?? false),
        'message': responseData['message'] ?? 'Authentication completed',
        'token': responseData['token'],
      };
    } catch (e) {
      return _handleError(e);
    }
  }

  // Metodă pentru înregistrare
  Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      ).timeout(_timeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Registration successful.',
        };
      }

      return {
        'success': false,
        'message': data['error'] ?? 'Registration failed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> unlockDoor() async {
    try {
      final response = await http.get(
        Uri.parse('$_doorLockUrl/unlock'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Ușa a fost deblocată'};
      }

      return {'success': false, 'message': 'Nu s-a putut debloca ușa'};
    } catch (e) {
      return {'success': false, 'message': 'Eroare la deblocare: $e'};
    }
  }

  // Metodă pentru trimiterea codului de resetare
  Future<Map<String, dynamic>> requestResetCode(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/request-reset-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(_timeout);

      final responseData = _handleResponse(response);
      return {
        'success': response.statusCode == 200,
        'message': responseData['message'] ?? 'Reset code sent to email',
      };
    } catch (e) {
      return _handleError(e);
    }
  }

  // Metodă pentru resetarea parolei
  Future<Map<String, dynamic>> resetPassword(
      String email, String code, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code.toUpperCase(),
          'newPassword': newPassword,
        }),
      ).timeout(_timeout);

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'success': response.statusCode == 200,
        'message': data['message'] ?? 'Password reset successfully',
        'token': data['token'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: ${e.toString()}',
      };
    }
  }

  // Helper pentru procesarea răspunsurilor
  Map<String, dynamic> _handleResponse(http.Response response) {
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  // Helper pentru gestionarea erorilor
  Map<String, dynamic> _handleError(dynamic error) {
    final errorMessage = error.toString().replaceAll(RegExp(r'^.*?: '), '');
    return {
      'success': false,
      'message': 'Error: ${errorMessage.isNotEmpty ? errorMessage : 'Unknown error'}',
    };
  }
}
