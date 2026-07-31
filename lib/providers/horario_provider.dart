import 'package:flutter/material.dart';
import '../models/horario.dart';
import '../models/marcado.dart';
import '../services/horario_service.dart';
import '../services/marcado_service.dart';

class HorarioProvider extends ChangeNotifier {
  final HorarioService _horarioService = HorarioService();
  final MarcadoService _marcadoService = MarcadoService();

  List<Horario> _horarios = [];
  List<Marcado> _marcadosHoy = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Horario> get horarios => _horarios;
  List<Marcado> get marcadosHoy => _marcadosHoy;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Cargar horarios del día
  Future<void> cargarHorarios() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _horarios = await _horarioService.getHorariosHoy();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cargar marcados de hoy
  Future<void> cargarMarcadosHoy() async {
    try {
      _marcadosHoy = await _marcadoService.getMarcadosHoy();
      notifyListeners();
    } catch (e) {
      // Ignorar
    }
  }

  // Refrescar todo
  Future<void> refrescarTodo() async {
    await cargarHorarios();
    await cargarMarcadosHoy();
  }

  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}