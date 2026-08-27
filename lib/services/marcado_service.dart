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
    try {
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

      print('Marcar entrada status: ${response.statusCode}');
      print('Marcar entrada body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Error al marcar entrada');
      }
    } catch (e) {
      print('Error en marcarEntrada: $e');
      rethrow;
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
    try {
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

      print('Marcar salida status: ${response.statusCode}');
      print('Marcar salida body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Error al marcar salida');
      }
    } catch (e) {
      print('Error en marcarSalida: $e');
      rethrow;
    }
  }

  // Historial con filtros
  Future<List<Marcado>> getHistorial({DateTime? fecha, int? mes}) async {
    try {
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

      print('Historial status: ${response.statusCode}');
      print('Historial body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        print('Keys en data: ${data.keys}');

        List<Marcado> marcados = [];

        if (data.containsKey('data') && data['data'] is List) {
          final List<dynamic> marcadosJson = data['data'] as List<dynamic>;
          print('Cantidad de items en data: ${marcadosJson.length}');

          if (marcadosJson.isNotEmpty) {
            print('Primer item: ${marcadosJson[0]}');
          }

          marcados = marcadosJson
              .map((json) {
                try {
                  return Marcado.fromJson(json);
                } catch (e) {
                  print('Error parseando item: $e');
                  print('Item: $json');
                  return null;
                }
              })
              .whereType<Marcado>()
              .toList();
        } else if (data.containsKey('marcados') && data['marcados'] is List) {
          final List<dynamic> marcadosJson = data['marcados'] as List<dynamic>;
          print('Cantidad de items en marcados: ${marcadosJson.length}');

          marcados = marcadosJson
              .map((json) {
                try {
                  return Marcado.fromJson(json);
                } catch (e) {
                  print('Error parseando item: $e');
                  return null;
                }
              })
              .whereType<Marcado>()
              .toList();
        } else if (data is List) {
          print('Data es directamente una lista');
          marcados = (data as List)
              .map((json) {
                try {
                  return Marcado.fromJson(json);
                } catch (e) {
                  print('Error parseando item: $e');
                  return null;
                }
              })
              .whereType<Marcado>()
              .toList();
        } else {
          print('No se encontraron marcados en la respuesta');
          return [];
        }

        print('Marcados parseados: ${marcados.length}');
        return marcados;
      } else {
        throw Exception('Error al obtener historial: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getHistorial: $e');
      rethrow;
    }
  }

  // Marcados de hoy
  Future<List<Marcado>> getMarcadosHoy() async {
    try {
      final response = await _apiService.get(ApiConfig.marcadosHoy);

      print('Marcados hoy status: ${response.statusCode}');
      print('Marcados hoy body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        List<Marcado> marcados = [];

        if (data.containsKey('data') && data['data'] is List) {
          final List<dynamic> marcadosJson = data['data'] as List<dynamic>;
          marcados = marcadosJson
              .map((json) {
                try {
                  return Marcado.fromJson(json);
                } catch (e) {
                  print('Error parseando item: $e');
                  return null;
                }
              })
              .whereType<Marcado>()
              .toList();
        } else if (data.containsKey('marcados') && data['marcados'] is List) {
          final List<dynamic> marcadosJson = data['marcados'] as List<dynamic>;
          marcados = marcadosJson
              .map((json) {
                try {
                  return Marcado.fromJson(json);
                } catch (e) {
                  print('Error parseando item: $e');
                  return null;
                }
              })
              .whereType<Marcado>()
              .toList();
        } else {
          return [];
        }

        return marcados;
      } else {
        throw Exception(
            'Error al obtener marcados de hoy: ${response.statusCode}');
      }
    } catch (e) {
      print('Error en getMarcadosHoy: $e');
      rethrow;
    }
  }
}
