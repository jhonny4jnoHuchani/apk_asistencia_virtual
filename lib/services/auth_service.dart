import 'dart:convert';
import 'dart:io';
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
      // La respuesta tiene formato { success: true, data: {...} }
      final userData = data['data'] ?? data;
      return User.fromJson(userData);
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

  // ============================================
  // MÉTODOS PARA FOTO DE PERFIL
  // ============================================

  /// Actualizar foto de perfil
  /// POST /api/auth/update-foto
  /// [imageFile] - Archivo de imagen a subir
  /// Retorna la respuesta del servidor con la URL de la foto
  Future<Map<String, dynamic>> updateFoto(File imageFile) async {
    try {
      final response = await _apiService.postMultipart(
        ApiConfig.updateFoto,
        fields: {},
        files: {'foto_perfil': imageFile},
      );

      // Leer el cuerpo de la respuesta
      final responseBody =
          await _apiService.getBodyFromStreamedResponse(response);

      print('[AuthService] updateFoto - Status: ${response.statusCode}');
      print('[AuthService] updateFoto - Response: $responseBody');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (responseBody['success'] == true) {
          return responseBody;
        } else {
          throw Exception(
              responseBody['message'] ?? 'Error al actualizar la foto');
        }
      } else {
        throw Exception(
            responseBody['message'] ?? 'Error al actualizar la foto');
      }
    } catch (e) {
      print('[AuthService] Error en updateFoto: $e');
      rethrow;
    }
  }

  /// Eliminar foto de perfil
  /// DELETE /api/auth/delete-foto
  /// Retorna la respuesta del servidor
  Future<Map<String, dynamic>> deleteFoto() async {
    try {
      final response = await _apiService.deleteAuth(ApiConfig.deleteFoto);

      print('[AuthService] deleteFoto - Status: ${response.statusCode}');
      print('[AuthService] deleteFoto - Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Error al eliminar la foto');
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Error al eliminar la foto');
      }
    } catch (e) {
      print('[AuthService] Error en deleteFoto: $e');
      rethrow;
    }
  }

  /// Obtener la URL de la foto de perfil del usuario actual
  /// Este método es útil para actualizar la foto después de subirla
  Future<String?> getFotoPerfilUrl() async {
    try {
      final user = await getPerfil();
      return user.fotoPerfilUrl;
    } catch (e) {
      print('[AuthService] Error al obtener URL de foto: $e');
      return null;
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
