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
  bool get necesitaRegistroFacial =>
      _user != null && !_registroFacialCompleto;
  bool get registroFacialCompleto => _registroFacialCompleto;
  int get embeddingsCount => _embeddingsCount;

  // Verificar si hay sesión activa al abrir la app
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
  Future<bool> cambiarPassword(String actual, String nueva, String confirmacion) async {
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
          primerLogin: false, // Ya cambió su contraseña
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

  // Actualizar perfil (después de registro facial)
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
      _registroFacialCompleto = estado['habilitado'] == true ||
          _embeddingsCount >= 50;
    } catch (e) {
      // Si falla la consulta (ej. docente aún sin ningún embedding),
      // asumimos que el registro facial no está completo para no
      // bloquear al usuario, pero tampoco lo dejamos pasar sin marcar.
      _registroFacialCompleto = false;
      _embeddingsCount = 0;
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

  // Obtener ID único del dispositivo
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
      // Si falla, generar un ID único
    }
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }
}