import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/marcado.dart';
import 'api_service.dart';

class MarcadoService {
  final ApiService _apiService = ApiService();

  // Marcar entrada
  Future<void> marcarEntrada({
    required int horarioId,
    required double latitud,
    required double longitud,
    required File fotoConstancia,
    required File fotoRostro,
  }) async {
    final streamedResponse = await _apiService.postMultipart(
      ApiConfig.marcarEntrada,
      fields: {
        'horario_id': horarioId.toString(),
        'latitud': latitud.toString(),
        'longitud': longitud.toString(),
      },
      files: {
        'foto_constancia': fotoConstancia,
        'foto_rostro': fotoRostro,
      },
    );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al marcar entrada');
    }
  }

  // Marcar salida
  Future<void> marcarSalida({
    required int horarioId,
    required double latitud,
    required double longitud,
    required File fotoConstancia,
    required File fotoRostro,
  }) async {
    final streamedResponse = await _apiService.postMultipart(
      ApiConfig.marcarSalida,
      fields: {
        'horario_id': horarioId.toString(),
        'latitud': latitud.toString(),
        'longitud': longitud.toString(),
      },
      files: {
        'foto_constancia': fotoConstancia,
        'foto_rostro': fotoRostro,
      },
    );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al marcar salida');
    }
  }

  // Historial con filtros
  Future<List<Marcado>> getHistorial({DateTime? fecha, int? mes}) async {
    String endpoint = ApiConfig.historial;
    final params = <String, String>{};

    if (fecha != null) {
      params['fecha'] = fecha.toIso8601String().split('T')[0];
    }
    if (mes != null) {
      params['mes'] = mes.toString();
    }

    if (params.isNotEmpty) {
      endpoint += '?${Uri(queryParameters: params).query}';
    }

    final response = await _apiService.get(endpoint);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> marcadosJson = data['marcados'] ?? data['data'] ?? [];
      return marcadosJson.map((json) => Marcado.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener historial');
    }
  }

  // Marcados de hoy
  Future<List<Marcado>> getMarcadosHoy() async {
    final response = await _apiService.get(ApiConfig.marcadosHoy);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> marcadosJson = data['marcados'] ?? data['data'] ?? [];
      return marcadosJson.map((json) => Marcado.fromJson(json)).toList();
    } else {
      throw Exception('Error al obtener marcados de hoy');
    }
  }
}