import 'package:flutter/material.dart';
import '../models/horario.dart';
import '../models/marcado.dart';
import '../services/horario_service.dart';
import '../services/marcado_service.dart';
import '../services/notification_service.dart';

class HorarioProvider extends ChangeNotifier {
  final HorarioService _horarioService = HorarioService();
  final MarcadoService _marcadoService = MarcadoService();
  final NotificationService _notificationService = NotificationService();

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

      // Avisos semanales que llegan aunque no se abra la app
      _programarAvisosSemana();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Pide el horario semanal y programa los avisos de toda la semana.
  // Si falla (sin internet), se mantienen los avisos que ya estaban.
  Future<void> _programarAvisosSemana() async {
    try {
      final semana = await _horarioService.getHorariosSemanal();
      await _notificationService.programarNotificacionesSemana(
          semana, _horarios);
    } catch (e) {
      print('[AVISOS] No se pudo programar la semana: $e');
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
