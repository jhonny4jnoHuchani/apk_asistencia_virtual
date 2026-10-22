import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';
import 'dart:math';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/reconocimiento_service.dart';
import '../deep_link_state.dart';

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
  // Restablecer contraseña con token - NO REQUIERE SESION
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

      if (response['success'] == true) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Error al restablecer la contraseña';
        _isLoading = false;
        notifyListeners();
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
    DeepLinkState.deepLinkHandled = false; // 🔧 resetear
    DeepLinkState.pendingUri = null; // 🔧 limpiar
    notifyListeners();
  }

  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Obtener ID unico de la instalacion.
  // Se genera un UUID v4 la primera vez y se guarda en el almacenamiento
  // seguro (Keystore/Keychain), asi se mantiene entre sesiones y logout,
  // y cambia solo si la app se desinstala o se borran sus datos.
  static const String _installationIdKey = 'installation_id';

  Future<String> _getDeviceId() async {
    try {
      final stored = await _storage.read(key: _installationIdKey);
      if (stored != null && stored.isNotEmpty) return stored;
    } catch (e) {
      // Datos ilegibles (ej. restaurados de un backup sin la clave del
      // Keystore): se descartan y se genera un ID nuevo
      await _storage.delete(key: _installationIdKey).catchError((_) {});
    }

    final nuevoId = _generarUuidV4();
    try {
      await _storage.write(key: _installationIdKey, value: nuevoId);
    } catch (e) {
      // Si no se puede guardar, se usa igual para este login
    }
    return nuevoId;
  }

  String _generarUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

// NUEVO MÉTODO: Establecer contraseña después del registro facial
  Future<bool> setPassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.setPassword(
        password: newPassword,
        passwordConfirmation: confirmPassword,
      );

      _isLoading = false;
      notifyListeners();

      if (response['success'] == true) {
        // Actualizar el usuario local
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
        return true;
      } else {
        _error = response['message'] ?? 'Error al establecer la contraseña';
        return false;
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // En AuthProvider

  /// Actualizar foto de perfil
  Future<bool> updateProfilePhoto(File imageFile) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.updateFoto(imageFile);

      if (response['success'] == true) {
        // Actualizar usuario local con la nueva foto
        final data = response['data'];
        if (_user != null && data != null) {
          _user = _user!.copyWith(
            fotoPerfil: data['foto_perfil'],
            fotoPerfilUrl: data['foto_perfil_url'],
          );
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Error al actualizar la foto';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Eliminar foto de perfil
  Future<bool> deleteProfilePhoto() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.deleteFoto();

      if (response['success'] == true) {
        // Actualizar usuario local
        if (_user != null) {
          _user = _user!.copyWith(
            fotoPerfil: null,
            fotoPerfilUrl: null,
          );
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Error al eliminar la foto';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
