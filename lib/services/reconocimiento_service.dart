import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'api_service.dart';

class ReconocimientoService {
  final ApiService _apiService = ApiService();

  // ============================================
  // REGISTRAR EMBEDDING FACIAL
  // POST /api/reconocimiento/registrar-embedding
  // Body: posicion + imagen
  // Respuesta: { success, total_embeddings, faltan }
  // ============================================
  Future<Map<String, dynamic>> registrarEmbedding({
    required String posicion,
    required File image,
  }) async {
    print('📤 ENVIANDO: posicion=$posicion, imagen=${image.path}');
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
    print('📥 RESPUESTA: ${response.statusCode} - ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al registrar embedding');
    }
  }

  // ============================================
  // VERIFICAR ROSTRO CON GESTO ALEATORIO
  // POST /api/reconocimiento/verificar
  // Body: gesto_solicitado + foto_frontal + foto_gesto
  // Respuesta: { match, gesture_detected, eyeglass_detected, spoofing_detected }
  // ============================================
  Future<Map<String, dynamic>> verificar({
    required String gestoSolicitado,
    required File fotoFrontal,
    required File fotoGesto,
  }) async {
    final streamedResponse = await _apiService.postMultipart(
      ApiConfig.verificar,
      fields: {
        'gesto_solicitado': gestoSolicitado,
      },
      files: {
        'foto_frontal': fotoFrontal,
        'foto_gesto': fotoGesto,
      },
    );

    final response = await http.Response.fromStream(streamedResponse);
    print('📥 VERIFICACIÓN: ${response.statusCode} - ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al verificar rostro');
    }
  }

  // ============================================
  // OBTENER ESTADO DEL REGISTRO FACIAL
  // GET /api/reconocimiento/estado/{docenteId}
  // Respuesta: { docente_id, activo, total_embeddings, habilitado }
  // ============================================
  Future<Map<String, dynamic>> getEstado(int docenteId) async {
    final response = await _apiService.get(
      ApiConfig.estadoReconocimiento(docenteId),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al obtener estado de reconocimiento');
    }
  }
}