import 'dart:convert';
import '../config/api_config.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  // Login - usa POST (publico para obtener token)
  Future<Map<String, dynamic>> login(
      String email, String password, String deviceId) async {
    final response = await _apiService.post(
      ApiConfig.login,
      {
        'email': email,
        'password': password,
        'device_id': deviceId,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _apiService.saveToken(data['token']);
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al iniciar sesion');
    }
  }

  // Cambiar contraseña - usa postAuth (protegido)
  Future<void> cambiarPassword(
      String actual, String nueva, String confirmacion) async {
    final response = await _apiService.postAuth(
      ApiConfig.cambiarPassword,
      {
        'password_actual': actual,
        'password_nueva': nueva,
        'password_nueva_confirmation': confirmacion,
      },
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al cambiar contraseña');
    }
  }

  // Forgot Password - usa post (publico, SIN autenticacion)
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    print('AuthService: Enviando solicitud de recuperacion para: $email');

    final response = await _apiService.post(
      ApiConfig.forgotPassword,
      {'email': email},
    );

    print('AuthService: Status: ${response.statusCode}');
    print('AuthService: Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al enviar el correo');
    }
  }

  // Reset Password - usa post (publico, SIN autenticacion)
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _apiService.post(
      ApiConfig.resetPassword,
      {
        'email': email,
        'token': token,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al restablecer la contraseña');
    }
  }

  // Obtener perfil - usa get (protegido)
  Future<User> getPerfil() async {
    final response = await _apiService.get(ApiConfig.perfil);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data['user'] ?? data);
    } else {
      throw Exception('Error al obtener perfil');
    }
  }

  // Establecer contraseña (requiere autenticación)
  Future<Map<String, dynamic>> setPassword({
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _apiService.postAuth(
      ApiConfig.setPassword,
      {
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al establecer la contraseña');
    }
  }

  // Logout - usa postAuth (protegido)
  Future<void> logout() async {
    try {
      final response = await _apiService.postAuth(ApiConfig.logout, {});
      print('Logout status: ${response.statusCode}');
    } catch (e) {
      print('Error en logout: $e');
    }
    await _apiService.deleteToken();
  }
}
