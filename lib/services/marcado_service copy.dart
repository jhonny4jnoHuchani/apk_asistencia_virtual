import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/marcado.dart';
import 'api_service.dart';

/// Resultado del marcado.
/// Permite saber si el gesto no coincidió aunque el marcado se haya guardado.
class MarcadoResult {
  final bool success;
  final bool gestoNoCoincide;
  final String message;

  MarcadoResult({
    required this.success,
    required this.gestoNoCoincide,
    required this.message,
  });
}

class MarcadoService {
  final ApiService _apiService = ApiService();

  // ---------------------------------------------------------------
  // Marcar entrada
  // ---------------------------------------------------------------
  Future<MarcadoResult> marcarEntrada({
    required int horarioId,
    required double latitud,
    required double longitud,
    required String gestoSolicitado,
    required File fotoFrontal,
    required File fotoGesto,
    File? fotoConstancia,
  }) async {
    try {
      final streamedResponse = await _apiService.postMultipart(
        ApiConfig.marcarEntrada,
        fields: {
          'horario_id': horarioId.toString(),
          'latitud': latitud.toString(),
          'longitud': longitud.toString(),
          'gesto_solicitado': gestoSolicitado,
        },
        files: {
          'foto_frontal': fotoFrontal,
          'foto_gesto': fotoGesto,
          if (fotoConstancia != null) 'foto_constancia': fotoConstancia,
        },
      );

      final response = await http.Response.fromStream(streamedResponse);
      print('Marcar entrada status: ${response.statusCode}');
      print('Marcar entrada body: ${response.body}');

      // Respuesta exitosa (201 Created)
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final gestoNoCoincide = data['gesto_no_coincide'] == true;
          final message = data['message']?.toString() ??
              'Entrada registrada correctamente.';
          return MarcadoResult(
            success: true,
            gestoNoCoincide: gestoNoCoincide,
            message: message,
          );
        }
        throw Exception(data['message'] ?? 'Error al marcar entrada');
      }

      // Errores específicos del servicio facial (400 Bad Request)
      if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        print('Error 400: $data');

        // Lentes detectados
        if (data['eyeglass_detected'] == true) {
          throw Exception('Quítate las gafas');
        }

        // Suplantación detectada
        if (data['resultado'] == 'spoofing_detectado') {
          throw Exception('Posible suplantación detectada');
        }

        // Identidad no coincide
        if (data['resultado'] == 'desconocido') {
          throw Exception(
              data['message'] ?? 'No se pudo verificar la identidad');
        }

        // Otros errores
        throw Exception(data['message'] ?? 'Error en la verificación');
      }

      // Conflicto (ya marcó)
      if (response.statusCode == 409) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Conflicto: Ya marcaste entrada');
      }

      // Sin permisos
      if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'No tienes permiso');
      }

      // No encontrado
      if (response.statusCode == 404) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Horario no encontrado');
      }

      // Error del servidor
      if (response.statusCode >= 500) {
        throw Exception('Error interno del servidor. Intenta nuevamente.');
      }

      // Cualquier otro error
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al marcar entrada');
    } catch (e) {
      print('Error en marcarEntrada: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------
  // Marcar salida
  // ---------------------------------------------------------------
  Future<MarcadoResult> marcarSalida({
    required int horarioId,
    required double latitud,
    required double longitud,
    required String gestoSolicitado,
    required File fotoFrontal,
    required File fotoGesto,
    File? fotoConstancia,
  }) async {
    try {
      final streamedResponse = await _apiService.postMultipart(
        ApiConfig.marcarSalida,
        fields: {
          'horario_id': horarioId.toString(),
          'latitud': latitud.toString(),
          'longitud': longitud.toString(),
          'gesto_solicitado': gestoSolicitado,
        },
        files: {
          'foto_frontal': fotoFrontal,
          'foto_gesto': fotoGesto,
          if (fotoConstancia != null) 'foto_constancia': fotoConstancia,
        },
      );

      final response = await http.Response.fromStream(streamedResponse);
      print('Marcar salida status: ${response.statusCode}');
      print('Marcar salida body: ${response.body}');

      // Respuesta exitosa (201 Created)
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final gestoNoCoincide = data['gesto_no_coincide'] == true;
          final message =
              data['message']?.toString() ?? 'Salida registrada correctamente.';
          return MarcadoResult(
            success: true,
            gestoNoCoincide: gestoNoCoincide,
            message: message,
          );
        }
        throw Exception(data['message'] ?? 'Error al marcar salida');
      }

      // Errores específicos del servicio facial (400 Bad Request)
      if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        print('Error 400: $data');

        if (data['eyeglass_detected'] == true) {
          throw Exception('Quítate las gafas');
        }

        if (data['resultado'] == 'spoofing_detectado') {
          throw Exception('Posible suplantación detectada');
        }

        if (data['resultado'] == 'desconocido') {
          throw Exception(
              data['message'] ?? 'No se pudo verificar la identidad');
        }

        throw Exception(data['message'] ?? 'Error en la verificación');
      }

      if (response.statusCode == 409) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Conflicto: Ya marcaste salida');
      }

      if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'No tienes permiso');
      }

      if (response.statusCode == 404) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Horario no encontrado');
      }

      if (response.statusCode >= 500) {
        throw Exception('Error interno del servidor. Intenta nuevamente.');
      }

      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Error al marcar salida');
    } catch (e) {
      print('Error en marcarSalida: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------
  // Historial con filtros
  // ---------------------------------------------------------------
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

  // ---------------------------------------------------------------
  // Marcados de hoy
  // ---------------------------------------------------------------
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
