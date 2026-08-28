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

    print('[API] GET: $endpoint');

    try {
      final response = await http.get(url, headers: headers);
      _checkUnauthorized(response);
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

    print('[API] POST Auth: $endpoint');
    print('[API] Body: $body');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      print('[API] Response status: ${response.statusCode}');
      print('[API] Response body: ${response.body}');
      _checkUnauthorized(response);
      return response;
    } catch (e) {
      throw Exception('Error de conexion: $e');
    }
  }

  // POST sin autenticacion (para endpoints publicos como forgot-password)
  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final headers = _getPublicHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    print('[API] POST Public: $endpoint');
    print('[API] Body: $body');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      print('[API] Response status: ${response.statusCode}');
      print('[API] Response body: ${response.body}');

      return response;
    } catch (e) {
      throw Exception('Error de conexion: $e');
    }
  }

  // PUT con autenticacion
  Future<http.Response> putAuth(
      String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    print('[API] PUT: $endpoint');
    print('[API] Body: $body');

    try {
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      print('[API] Response status: ${response.statusCode}');
      _checkUnauthorized(response);
      return response;
    } catch (e) {
      throw Exception('Error de conexion: $e');
    }
  }

  // DELETE con autenticacion - NUEVO METODO
  Future<http.Response> deleteAuth(String endpoint) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    print('[API] DELETE: $endpoint');

    try {
      final response = await http.delete(
        url,
        headers: headers,
      );
      print('[API] Response status: ${response.statusCode}');
      _checkUnauthorized(response);
      return response;
    } catch (e) {
      throw Exception('Error de conexion: $e');
    }
  }

  // PATCH con autenticacion
  Future<http.Response> patchAuth(
      String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    print('[API] PATCH: $endpoint');
    print('[API] Body: $body');

    try {
      final response = await http.patch(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      print('[API] Response status: ${response.statusCode}');
      _checkUnauthorized(response);
      return response;
    } catch (e) {
      throw Exception('Error de conexion: $e');
    }
  }

  // ============================================
  // METODOS MULTIPART
  // ============================================

  // POST MULTIPART con un solo archivo
  Future<http.StreamedResponse> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    required Map<String, File> files,
  }) async {
    final headers = await _getMultipartHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    print('[API] POST Multipart: $endpoint');
    print('[API] Fields: $fields');
    print('[API] Files: ${files.keys}');

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
        print('[API] Archivo agregado: ${entry.key} - ${entry.value.path}');
      } else {
        print('[API] Archivo no existe: ${entry.key} - ${entry.value.path}');
      }
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      _checkUnauthorized(response);
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

  // POST MULTIPART con multiples archivos - NUEVO METODO
  Future<http.StreamedResponse> postMultipartWithFiles(
    String endpoint, {
    required Map<String, String> fields,
    required List<MapEntry<String, File>> files,
  }) async {
    final headers = await _getMultipartHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    print('[API] POST Multipart (multiple): $endpoint');
    print('[API] Fields: $fields');
    print('[API] Files: ${files.map((e) => e.key)}');

    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(headers);

    // Agregar campos de texto
    request.fields.addAll(fields);

    // Agregar archivos
    for (final entry in files) {
      if (await entry.value.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath(entry.key, entry.value.path),
        );
        print('[API] Archivo agregado: ${entry.key} - ${entry.value.path}');
      } else {
        print('[API] Archivo no existe: ${entry.key} - ${entry.value.path}');
      }
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      _checkUnauthorized(response);
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
  // METODOS PARA DESCARGA DE ARCHIVOS
  // ============================================

  // GET para descargar archivos (ej: imagenes, PDFs)
  Future<http.Response> download(String endpoint) async {
    final headers = await _getHeaders();
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    print('[API] Download: $endpoint');

    try {
      final response = await http.get(url, headers: headers);
      _checkUnauthorized(response);
      return response;
    } catch (e) {
      throw Exception('Error al descargar archivo: $e');
    }
  }

  // ============================================
  // MANEJO DE TOKEN
  // ============================================

  // Verificar si el token expiro (401)
  void _checkUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      _storage.delete(key: 'token');
      throw Exception('Sesion expirada. Inicie sesion nuevamente.');
    }
  }

  // Guardar token
  Future<void> saveToken(String token) async {
    print('[API] Token guardado: ${token.substring(0, 20)}...');
    await _storage.write(key: 'token', value: token);
  }

  // Obtener token
  Future<String?> getToken() async {
    final token = await _storage.read(key: 'token');
    if (token != null) {
      print('[API] Token recuperado: ${token.substring(0, 20)}...');
    } else {
      print('[API] Token no encontrado');
    }
    return token;
  }

  // Eliminar token
  Future<void> deleteToken() async {
    await _storage.delete(key: 'token');
    print('[API] Token eliminado');
  }

  // Verificar si hay token guardado
  Future<bool> hasToken() async {
    final token = await _storage.read(key: 'token');
    return token != null && token.isNotEmpty;
  }

  // ============================================
  // METODOS DE UTILIDAD
  // ============================================

  // Construir URL con query parameters
  String buildUrl(String endpoint, Map<String, dynamic>? queryParams) {
    if (queryParams == null || queryParams.isEmpty) {
      return endpoint;
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    return uri
        .replace(queryParameters: queryParams.map(
          (key, value) {
            return MapEntry(key, value.toString());
          },
        ))
        .toString()
        .replaceFirst(ApiConfig.baseUrl, '');
  }

  // Parsear respuesta de error
  String parseErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data['message'] ?? data['error'] ?? 'Error desconocido';
    } catch (e) {
      return 'Error al procesar la respuesta del servidor';
    }
  }

  // Verificar si la respuesta fue exitosa
  bool isSuccess(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  // Obtener el body como mapa
  Future<Map<String, dynamic>> getBodyAsMap(http.Response response) async {
    try {
      return jsonDecode(response.body);
    } catch (e) {
      return {};
    }
  }

  // Cerrar el cliente (para limpieza)
  void dispose() {
    // http.Client no necesita dispose en versiones recientes
  }
}
