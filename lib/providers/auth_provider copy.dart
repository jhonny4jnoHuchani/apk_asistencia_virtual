import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/reconocimiento_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ReconocimientoService _reconocimientoService = ReconocimientoService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  User? _user;
  bool _isLoading = false;
  String? _error;

  // Estado real del registro facial, obtenido de
  // GET /reconocimiento/estado/{docenteId} (no confiamos en que
  // /auth/login o /auth/perfil incluyan estos campos en el user).
  bool _registroFacialCompleto = false;
  int _embeddingsCount = 0;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get necesitaCambiarPassword => _user?.primerLogin ?? false;
  bool get necesitaRegistroFacial => _user != null && !_registroFacialCompleto;
  bool get registroFacialCompleto => _registroFacialCompleto;
  int get embeddingsCount => _embeddingsCount;

  // NUEVO GETTER: Obtener el token almacenado
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: 'token');
    } catch (e) {
      return null;
    }
  }

  // Verificar si hay sesion activa al abrir la app
  Future<bool> checkAuthStatus() async {
    try {
      final token = await _storage.read(key: 'token');
      if (token == null || token.isEmpty) return false;

      _user = await _authService.getPerfil();
      await _cargarEstadoFacial();
      notifyListeners();
      return true;
    } catch (e) {
      await _storage.delete(key: 'token');
      _user = null;
      return false;
    }
  }

  // Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final deviceId = await _getDeviceId();
      final response = await _authService.login(email, password, deviceId);

      _user = User.fromJson(response['user']);
      await _cargarEstadoFacial();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Cambiar contraseña (primer login)
  Future<bool> cambiarPassword(
      String actual, String nueva, String confirmacion) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.cambiarPassword(actual, nueva, confirmacion);

      // Actualizar usuario local
      if (_user != null) {
        _user = User(
          id: _user!.id,
          nombreCompleto: _user!.nombreCompleto,
          email: _user!.email,
          rol: _user!.rol,
          primerLogin: false,
          embeddingsCount: _user!.embeddingsCount,
          registroFacialCompleto: _user!.registroFacialCompleto,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Enviar enlace de recuperacion de contraseña
  Future<bool> sendPasswordResetLink(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('AuthProvider: Enviando solicitud de recuperacion para: $email');

      final response = await _authService.forgotPassword(email);

      _isLoading = false;
      notifyListeners();

      print('AuthProvider: Respuesta recibida: $response');

      if (response['success'] == true) {
        return true;
      } else {
        _error = response['message'] ?? 'Error al enviar el correo';
        return false;
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      print('AuthProvider: Error: $_error');
      return false;
    }
  }

  // Restablecer contraseña con token
  Future<bool> resetPassword({
    required String email,
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.resetPassword(
        email: email,
        token: token,
        password: newPassword,
        passwordConfirmation: confirmPassword,
      );

      _isLoading = false;
      notifyListeners();

      if (response['success'] == true) {
        return true;
      } else {
        _error = response['message'] ?? 'Error al restablecer la contraseña';
        return false;
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Actualizar perfil (despues de registro facial)
  Future<void> actualizarPerfil() async {
    try {
      _user = await _authService.getPerfil();
      await _cargarEstadoFacial();
      notifyListeners();
    } catch (e) {
      // Ignorar
    }
  }

  // Consulta GET /reconocimiento/estado/{docenteId} y actualiza el
  // estado local. Es la fuente de verdad del registro facial, en vez
  // de depender de campos que puedan faltar en /auth/login o /auth/perfil.
  Future<void> _cargarEstadoFacial() async {
    if (_user == null) return;
    try {
      final estado = await _reconocimientoService.getEstado(_user!.id);
      _embeddingsCount = estado['total_embeddings'] ?? 0;
      _registroFacialCompleto =
          estado['habilitado'] == true || _embeddingsCount >= 50;
    } catch (e) {
      // Si falla la consulta (ej. docente aun sin ningun embedding),
      // asumimos que el registro facial no esta completo para no
      // bloquear al usuario, pero tampoco lo dejamos pasar sin marcar.
      _registroFacialCompleto = false;
      _embeddingsCount = 0;
    }
  }

  // Verificar token y limpiar si es invalido
  Future<bool> validarToken() async {
    try {
      final token = await _storage.read(key: 'token');
      if (token == null || token.isEmpty) {
        return false;
      }

      // Intentar obtener perfil para validar token
      await _authService.getPerfil();
      return true;
    } catch (e) {
      // Si hay error, limpiar token
      await _storage.delete(key: 'token');
      _user = null;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _error = null;
    notifyListeners();
  }

  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Obtener ID unico del dispositivo
  Future<String> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown';
      }
    } catch (e) {
      // Si falla, generar un ID unico
    }
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }
}
