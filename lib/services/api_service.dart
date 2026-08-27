import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ============================================
  // HEADERS
  // ============================================

  // Headers para peticiones JSON con autenticacion
  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'token');
    return {
      'Authorization': 'Bearer ${token ?? ''}',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  // Headers para multipart (sin Content-Type, lo pone http.MultipartRequest)
  Future<Map<String, String>> _getMultipartHeaders() async {
    final token = await _storage.read(key: 'token');
    return {
      'Authorization': 'Bearer ${token ?? ''}',
      'Accept': 'application/json',
    };
  }

  // Headers sin autenticacion (para recuperacion de contraseña)
  Map<String, String> _getPublicHeaders() {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  // ============================================
  // METODOS HTTP
  // ============================================

  // GET con autenticacion
  Future<http.Response> get(String endpoint) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    print('GET request a: $endpoint');

    try {
      final response = await http.get(url, headers: headers);
      checkUnauthorized(response);
      return response;
    } catch (e) {
      throw Exception('Error de conexion: $e');
    }
  }

  // POST con autenticacion (para endpoints protegidos)
  Future<http.Response> postAuth(
      String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    print('POST auth a: $endpoint');
    print('Body: $body');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      checkUnauthorized(response);
      return response;
    } catch (e) {
      throw Exception('Error de conexion: $e');
    }
  }

  // POST sin autenticacion (para endpoints publicos como forgot-password)
  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final headers = _getPublicHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    print('POST public a: $endpoint');
    print('Body: $body');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      // No verificamos 401 porque este endpoint es publico
      return response;
    } catch (e) {
      throw Exception('Error de conexion: $e');
    }
  }

  // POST MULTIPART (para enviar fotos con autenticacion)
  Future<http.StreamedResponse> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    required Map<String, File> files,
  }) async {
    final headers = await _getMultipartHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    print('POST multipart a: $endpoint');
    print('Fields: $fields');

    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(headers);

    // Agregar campos de texto
    request.fields.addAll(fields);

    // Agregar archivos
    for (final entry in files.entries) {
      if (await entry.value.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath(entry.key, entry.value.path),
        );
        print('Archivo agregado: ${entry.key} - ${entry.value.path}');
      } else {
        print('Archivo no existe: ${entry.key} - ${entry.value.path}');
      }
    }

    try {
      final streamedResponse = await request.send();
      // Convertimos a Response solo para poder inspeccionar el status code
      // y detectar 401 sin consumir el stream para el llamador.
      final response = await http.Response.fromStream(streamedResponse);
      checkUnauthorized(response);
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
      );
    } catch (e) {
      if (e is Exception && e.toString().contains('Sesion expirada')) rethrow;
      throw Exception('Error al enviar archivos: $e');
    }
  }

  // ============================================
  // MANEJO DE TOKEN
  // ============================================

  // Verificar si el token expiro (401)
  void checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      _storage.delete(key: 'token');
      throw Exception('Sesion expirada. Inicie sesion nuevamente.');
    }
  }

  // Guardar token
  Future<void> saveToken(String token) async {
    print('Token guardado: ${token.substring(0, 20)}...');
    await _storage.write(key: 'token', value: token);
  }

  // Obtener token
  Future<String?> getToken() async {
    final token = await _storage.read(key: 'token');
    if (token != null) {
      print('Token recuperado: ${token.substring(0, 20)}...');
    } else {
      print('Token no encontrado');
    }
    return token;
  }

  // Eliminar token
  Future<void> deleteToken() async {
    await _storage.delete(key: 'token');
    print('Token eliminado');
  }
}
