import 'dart:convert';
import '../config/api_config.dart';
import '../models/horario.dart';
import '../models/clase_semanal.dart';
import 'api_service.dart';

class HorarioService {
  final ApiService _apiService = ApiService();

  Future<List<Horario>> getHorariosHoy() async {
    final response = await _apiService.get(ApiConfig.horariosHoy);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> horariosJson = data['data'] ?? [];
      return horariosJson
          .map((json) {
            try {
              return Horario.fromJson(json);
            } catch (e) {
              print('[HorarioService] Error parseando horario individual: $e');
              print('[HorarioService] JSON defectuoso: $json');
              return null;
            }
          })
          .whereType<Horario>()
          .toList();
    } else {
      // Mostrar el error real
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  }

  // Horario semanal. El backend responde:
  // { success, total_clases_semana, dias: { lunes: [...], martes: [...] } }
  // Tambien acepta "data" como lista o agrupada por dia. Si viene agrupado,
  // el dia se toma de la clave.
  Future<List<ClaseSemanal>> getHorariosSemanal() async {
    final response = await _apiService.get(ApiConfig.horariosSemanal);
    print('[SEMANAL] Código HTTP: ${response.statusCode}');
    print('[SEMANAL] Respuesta: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }

    final body = jsonDecode(response.body);
    final data = body is Map ? (body['dias'] ?? body['data']) : body;

    final clases = <ClaseSemanal>[];
    void agregar(dynamic json, String? dia) {
      if (json is! Map<String, dynamic>) return;
      try {
        clases.add(ClaseSemanal.fromJson(json, dia: dia));
      } catch (e) {
        print('[HorarioService] Error parseando horario semanal: $e');
        print('[HorarioService] JSON defectuoso: $json');
      }
    }

    if (data is List) {
      for (final json in data) {
        agregar(json, null);
      }
    } else if (data is Map) {
      data.forEach((dia, lista) {
        if (lista is! List) return;
        for (final json in lista) {
          agregar(json, dia.toString());
        }
      });
    }
    return clases;
  }
}
