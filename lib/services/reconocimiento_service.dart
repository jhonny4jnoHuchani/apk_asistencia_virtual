// lib/services/reconocimiento_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart'; // <-- AGREGAR ESTA IMPORTACION
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'api_service.dart';

class ReconocimientoService {
  final ApiService _apiService = ApiService();

  // ============================================
  // REGISTRAR EMBEDDING FACIAL
  // POST /api/reconocimiento/registrar-embedding
  // ============================================
  Future<Map<String, dynamic>> registrarEmbedding({
    required String posicion,
    required File image,
  }) async {
    try {
      _logRequest('registrarEmbedding', {
        'posicion': posicion,
        'imagen': image.path,
      });

      final streamedResponse = await _apiService.postMultipart(
        ApiConfig.registrarEmbedding,
        fields: {
          'posicion': posicion,
        },
        files: {
          'imagen': image,
        },
      );

      final response = await http.Response.fromStream(streamedResponse);
      _logResponse(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return _validateResponse(data);
      } else {
        final error = _parseErrorResponse(response.body);
        throw Exception(error);
      }
    } catch (e) {
      _logError('registrarEmbedding', e);
      rethrow;
    }
  }

  // ============================================
  // VERIFICAR ROSTRO CON GESTO (DOS FOTOS)
  // POST /api/reconocimiento/verificar
  // ============================================
  Future<Map<String, dynamic>> verificar({
    required String gestoSolicitado,
    required File fotoFrontal,
    required File fotoGesto,
  }) async {
    try {
      _logRequest('verificar', {
        'gesto_solicitado': gestoSolicitado,
        'foto_frontal': fotoFrontal.path,
        'foto_gesto': fotoGesto.path,
      });

      final streamedResponse = await _apiService.postMultipartWithFiles(
        ApiConfig.verificar,
        fields: {
          'gesto_solicitado': gestoSolicitado,
        },
        files: [
          MapEntry('foto_frontal', fotoFrontal),
          MapEntry('foto_gesto', fotoGesto),
        ],
      );

      final response = await http.Response.fromStream(streamedResponse);
      _logResponse(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return _validateResponse(data);
      } else {
        final error = _parseErrorResponse(response.body);
        throw Exception(error);
      }
    } catch (e) {
      _logError('verificar', e);
      rethrow;
    }
  }

  // ============================================
  // VERIFICAR ROSTRO CON UNA SOLA FOTO
  // POST /api/reconocimiento/verificar-simple
  // ============================================
  Future<Map<String, dynamic>> verificarSimple({
    required File image,
  }) async {
    try {
      _logRequest('verificarSimple', {
        'imagen': image.path,
      });

      final streamedResponse = await _apiService.postMultipart(
        ApiConfig.verificarSimple,
        fields: {},
        files: {
          'imagen': image,
        },
      );

      final response = await http.Response.fromStream(streamedResponse);
      _logResponse(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return _validateResponse(data);
      } else {
        final error = _parseErrorResponse(response.body);
        throw Exception(error);
      }
    } catch (e) {
      _logError('verificarSimple', e);
      rethrow;
    }
  }

  // ============================================
  // OBTENER POSICIONES DISPONIBLES
  // GET /api/reconocimiento/posiciones
  // ============================================
  Future<List<Map<String, dynamic>>> getPosiciones() async {
    try {
      final response = await _apiService.get(
        ApiConfig.posicionesReconocimiento,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['posiciones'] ?? []);
      } else {
        throw Exception('Error al obtener posiciones');
      }
    } catch (e) {
      _logError('getPosiciones', e);
      rethrow;
    }
  }

  // ============================================
  // OBTENER ESTADO DEL REGISTRO FACIAL
  // GET /api/reconocimiento/estado/{docenteId}
  // ============================================
  Future<Map<String, dynamic>> getEstado(int docenteId) async {
    try {
      _logRequest('getEstado', {'docenteId': docenteId});

      final response = await _apiService.get(
        ApiConfig.estadoReconocimiento(docenteId),
      );

      _logResponse(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _validateResponse(data);
      } else {
        final error = _parseErrorResponse(response.body);
        throw Exception(error);
      }
    } catch (e) {
      _logError('getEstado', e);
      rethrow;
    }
  }

  // ============================================
  // OBTENER MI ESTADO (DOCENTE AUTENTICADO)
  // GET /api/reconocimiento/mi-estado
  // ============================================
  Future<Map<String, dynamic>> getMiEstado() async {
    try {
      final response = await _apiService.get(
        ApiConfig.miEstadoReconocimiento,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _validateResponse(data);
      } else {
        final error = _parseErrorResponse(response.body);
        throw Exception(error);
      }
    } catch (e) {
      _logError('getMiEstado', e);
      rethrow;
    }
  }

  // ============================================
  // ELIMINAR EMBEDDINGS (SOLO ADMIN)
  // DELETE /api/reconocimiento/eliminar-embeddings/{docenteId}
  // ============================================
  Future<Map<String, dynamic>> eliminarEmbeddings(int docenteId) async {
    try {
      _logRequest('eliminarEmbeddings', {'docenteId': docenteId});

      final response = await _apiService.deleteAuth(
        ApiConfig.eliminarEmbeddings(docenteId),
      );

      _logResponse(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _validateResponse(data);
      } else {
        final error = _parseErrorResponse(response.body);
        throw Exception(error);
      }
    } catch (e) {
      _logError('eliminarEmbeddings', e);
      rethrow;
    }
  }

  // ============================================
  // OBTENER HISTORIAL DE VERIFICACIONES
  // GET /api/reconocimiento/historial/{docenteId}
  // ============================================
  Future<List<Map<String, dynamic>>> getHistorialVerificaciones(
      int docenteId) async {
    try {
      final response = await _apiService.get(
        ApiConfig.historialVerificaciones(docenteId),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['historial'] ?? []);
      } else {
        throw Exception('Error al obtener historial');
      }
    } catch (e) {
      _logError('getHistorialVerificaciones', e);
      rethrow;
    }
  }

  // ============================================
  // METODOS DE UTILIDAD PARA VERIFICACION DE RESPUESTAS
  // ============================================

  /// Verifica si el registro facial está completo
  bool isRegistroCompleto(Map<String, dynamic> estado) {
    return estado['habilitado'] == true;
  }

  /// Obtiene el número de embeddings registrados
  int getEmbeddingsCount(Map<String, dynamic> estado) {
    return estado['total_embeddings'] ?? 0;
  }

  /// Obtiene el número de embeddings faltantes
  int getEmbeddingsFaltantes(Map<String, dynamic> estado) {
    final total = estado['total_embeddings'] ?? 0;
    final requeridos = estado['embeddings_requeridos'] ?? 76;
    return (requeridos - total).clamp(0, requeridos);
  }

  /// Obtiene la calidad promedio de los embeddings
  double getCalidadPromedio(Map<String, dynamic> estado) {
    return (estado['calidad_promedio'] ?? 0.0).toDouble();
  }

  /// Verifica si se detectó suplantación (spoofing)
  bool isSpoofingDetected(Map<String, dynamic> response) {
    return response['resultado'] == 'spoofing_detectado' ||
        response.containsKey('liveness_score');
  }

  /// Verifica si se detectaron lentes
  bool isEyeglassDetected(Map<String, dynamic> response) {
    return response['eyeglass_detected'] == true;
  }

  /// Verifica si el gesto es válido
  bool isGestureValid(Map<String, dynamic> response) {
    return response['gesture_detected'] == true;
  }

  /// Verifica si hay coincidencia (match)
  bool isMatchFound(Map<String, dynamic> response) {
    return response['match'] == true;
  }

  /// Obtiene el nivel de confianza
  double getConfidence(Map<String, dynamic> response) {
    return (response['confianza'] ?? 0.0).toDouble();
  }

  /// Obtiene el mensaje de resultado
  String getResultadoMessage(Map<String, dynamic> response) {
    // Verificar detección de lentes primero
    if (isEyeglassDetected(response)) {
      return 'Por favor, quítese las gafas para continuar';
    }
    // Verificar suplantación
    if (isSpoofingDetected(response)) {
      return 'Posible suplantación detectada';
    }
    // Verificar gesto
    if (!isGestureValid(response)) {
      return 'El gesto no coincide';
    }
    // Verificar coincidencia
    if (isMatchFound(response)) {
      return 'Rostro verificado correctamente';
    }
    return 'Rostro no reconocido';
  }

  /// Obtiene el mensaje específico para lentes
  String getEyeglassMessage(Map<String, dynamic> response) {
    if (isEyeglassDetected(response)) {
      return response['message'] ??
          'Por favor, quítese las gafas para continuar';
    }
    return '';
  }

  /// Verifica si el error es por lentes
  bool isEyeglassError(Map<String, dynamic> response) {
    return isEyeglassDetected(response) ||
        (response['message']?.contains('gafas') ?? false) ||
        (response['message']?.contains('lentes') ?? false);
  }

  /// Obtiene el tipo de resultado (para mostrar iconos)
  ResultType getResultType(Map<String, dynamic> response) {
    if (isEyeglassDetected(response)) {
      return ResultType.eyeglass;
    }
    if (isSpoofingDetected(response)) {
      return ResultType.spoofing;
    }
    if (isMatchFound(response)) {
      return ResultType.success;
    }
    if (!isGestureValid(response) && response.containsKey('gesture_detected')) {
      return ResultType.gestureError;
    }
    return ResultType.unknown;
  }

  /// Obtiene el color asociado al resultado
  Color getResultColor(Map<String, dynamic> response) {
    final type = getResultType(response);
    switch (type) {
      case ResultType.eyeglass:
        return Colors.orange;
      case ResultType.spoofing:
        return Colors.red;
      case ResultType.success:
        return Colors.green;
      case ResultType.gestureError:
        return Colors.yellow.shade700;
      case ResultType.unknown:
        return Colors.grey;
    }
  }

  /// Obtiene el icono asociado al resultado
  IconData getResultIcon(Map<String, dynamic> response) {
    final type = getResultType(response);
    switch (type) {
      case ResultType.eyeglass:
        return Icons.visibility_off_rounded;
      case ResultType.spoofing:
        return Icons.warning_rounded;
      case ResultType.success:
        return Icons.check_circle_rounded;
      case ResultType.gestureError:
        return Icons.accessibility_new_rounded;
      case ResultType.unknown:
        return Icons.help_rounded;
    }
  }

  /// Obtiene el título del resultado
  String getResultTitle(Map<String, dynamic> response) {
    final type = getResultType(response);
    switch (type) {
      case ResultType.eyeglass:
        return 'Gafas detectadas';
      case ResultType.spoofing:
        return 'Suplantación detectada';
      case ResultType.success:
        return 'Verificación exitosa';
      case ResultType.gestureError:
        return 'Gesto incorrecto';
      case ResultType.unknown:
        return 'Resultado desconocido';
    }
  }

  // ============================================
  // METODOS PRIVADOS
  // ============================================

  Map<String, dynamic> _validateResponse(Map<String, dynamic> data) {
    if (!data.containsKey('success')) {
      data['success'] = true;
    }
    return data;
  }

  String _parseErrorResponse(String body) {
    try {
      final error = jsonDecode(body);
      return error['message'] ?? error['error'] ?? 'Error desconocido';
    } catch (e) {
      return 'Error al procesar la respuesta del servidor';
    }
  }

  void _logRequest(String method, Map<String, dynamic> params) {
    print('[RECONOCIMIENTO] Request: $method');
    print('[RECONOCIMIENTO] Params: $params');
  }

  void _logResponse(http.Response response) {
    print('[RECONOCIMIENTO] Response: ${response.statusCode}');
    if (response.body.isNotEmpty) {
      print('[RECONOCIMIENTO] Body: ${response.body}');
    }
  }

  void _logError(String method, dynamic error) {
    print('[RECONOCIMIENTO] Error en $method: $error');
  }
}

// ============================================
// ENUM PARA TIPOS DE RESULTADO
// ============================================
enum ResultType {
  eyeglass,
  spoofing,
  success,
  gestureError,
  unknown,
}
