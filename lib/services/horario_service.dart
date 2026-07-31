import 'dart:convert';
import '../config/api_config.dart';
import '../models/horario.dart';
import 'api_service.dart';

class HorarioService {
  final ApiService _apiService = ApiService();

  Future<List<Horario>> getHorariosHoy() async {
    final response = await _apiService.get(ApiConfig.horariosHoy);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> horariosJson = data['data'] ?? [];
      return horariosJson.map((json) => Horario.fromJson(json)).toList();
    } else {
      // Mostrar el error real
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  }
}