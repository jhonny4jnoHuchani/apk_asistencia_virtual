import 'dart:convert';
import '../config/api_config.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  // Login
  Future<Map<String, dynamic>> login(String email, String password, String deviceId) async {
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
      throw Exception(error['message'] ?? 'Error al iniciar sesión');
    }
  }

  // Cambiar contraseña
  Future<void> cambiarPassword(String actual, String nueva, String confirmacion) async {
    final response = await _apiService.post(
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

  // Obtener perfil
  Future<User> getPerfil() async {
    final response = await _apiService.get(ApiConfig.perfil);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data['user'] ?? data);
    } else {
      throw Exception('Error al obtener perfil');
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _apiService.post(ApiConfig.logout, {});
    } catch (e) {
      // Ignorar error si el servidor no responde
    }
    await _apiService.deleteToken();
  }
}