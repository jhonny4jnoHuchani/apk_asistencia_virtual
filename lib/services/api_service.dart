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
  
  // Headers para peticiones JSON normales
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

  // ============================================
  // MÉTODOS HTTP
  // ============================================

  // GET
  Future<http.Response> get(String endpoint) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    try {
      final response = await http.get(url, headers: headers);
      checkUnauthorized(response);
      return response;
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // POST (JSON)
  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      checkUnauthorized(response);
      return response;
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // POST MULTIPART (para enviar fotos)
  Future<http.StreamedResponse> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    required Map<String, File> files,
  }) async {
    final headers = await _getMultipartHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(headers);

    // Agregar campos de texto
    request.fields.addAll(fields);

    // Agregar archivos
    for (final entry in files.entries) {
      request.files.add(
        await http.MultipartFile.fromPath(entry.key, entry.value.path),
      );
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
      if (e is Exception && e.toString().contains('Sesión expirada')) rethrow;
      throw Exception('Error al enviar archivos: $e');
    }
  }

  // ============================================
  // MANEJO DE TOKEN
  // ============================================

  // Verificar si el token expiró (401)
  void checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      _storage.delete(key: 'token');
      throw Exception('Sesión expirada. Inicie sesión nuevamente.');
    }
  }

  // Guardar token
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'token', value: token);
  }

  // Obtener token
  Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  // Eliminar token
  Future<void> deleteToken() async {
    await _storage.delete(key: 'token');
  }
}