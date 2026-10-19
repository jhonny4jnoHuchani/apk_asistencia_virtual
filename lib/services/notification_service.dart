import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/horario.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String _channelId = 'asistencia_canal_recordatorios';
  static const String _channelName = 'Recordatorios de Marcado';
  static const String _channelDescription =
      'Notificaciones para avisar cuando se habilita el marcado de clases';

  Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Inicializar base de datos de zonas horarias
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('America/La_Paz'));
      } catch (_) {
        // Fallback si la ubicación no está disponible
      }

      // 2. Configuración para Android
      const androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      // 3. Configuración para iOS (compatibilidad)
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          debugPrint(
              '[NotificationService] Notificación tocada con payload: ${details.payload}');
        },
      );

      // 4. Crear canal de notificación para Android
      final androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
      }

      _initialized = true;
      debugPrint('[NotificationService] Inicializado correctamente.');
    } catch (e) {
      debugPrint('[NotificationService] Error al inicializar: $e');
    }
  }

  /// Solicitar permisos de notificación en Android 13+
  Future<bool> requestPermissions() async {
    try {
      await init();
      if (Platform.isAndroid) {
        final androidPlugin =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final granted =
              await androidPlugin.requestNotificationsPermission() ?? false;
          try {
            await androidPlugin.requestExactAlarmsPermission();
          } catch (_) {}
          return granted;
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error al pedir permisos: $e');
    }
    return false;
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/launcher_icon',
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  /// Muestra una notificación inmediata (ideal para pruebas y demostración al jefe)
  Future<void> mostrarNotificacionInmediata({
    int id = 9999,
    required String titulo,
    required String cuerpo,
    String? payload,
  }) async {
    try {
      await init();
      await _notificationsPlugin.show(
        id: id,
        title: titulo,
        body: cuerpo,
        notificationDetails: _notificationDetails(),
        payload: payload,
      );
    } catch (e) {
      debugPrint(
          '[NotificationService] Error en mostrarNotificacionInmediata: $e');
    }
  }

  /// Programa las notificaciones de entrada y salida para los horarios del día
  Future<void> programarNotificacionesHorarios(List<Horario> horarios) async {
    await init();
    final ahora = DateTime.now();

    for (final horario in horarios) {
      // --- 1. RECORDATORIO DE ENTRADA ---
      // Se programa si el docente aún no marcó entrada
      if (!horario.yaMarcoEntrada && horario.horaInicio.isNotEmpty) {
        try {
          final inicioParts = horario.horaInicio.split(':');
          if (inicioParts.length >= 2) {
            final hora = int.parse(inicioParts[0]);
            final minuto = int.parse(inicioParts[1]);

            final inicioClase = DateTime(
              ahora.year,
              ahora.month,
              ahora.day,
              hora,
              minuto,
            );

            // Ventana de entrada: se habilita 30 minutos antes
            final momentoHabilitado =
                inicioClase.subtract(const Duration(minutes: 30));

            if (momentoHabilitado.isAfter(ahora)) {
              await _programarAlarma(
                id: (horario.id * 10) + 1,
                fechaHora: momentoHabilitado,
                titulo: '🔔 ¡Marcado Habilitado!',
                cuerpo:
                    'Ya puedes registrar tu entrada para ${horario.materia} (${horario.paralelo}).',
                payload: 'entrada_${horario.id}',
              );
            }
          }
        } catch (e) {
          debugPrint('[NotificationService] Error calculando entrada: $e');
        }
      }

      // --- 2. RECORDATORIO DE SALIDA ---
      // Se programa para avisar cuando termina la clase (o 5 min antes)
      if (horario.horaFin.isNotEmpty && !horario.yaMarcoSalida) {
        try {
          final finParts = horario.horaFin.split(':');
          if (finParts.length >= 2) {
            final hora = int.parse(finParts[0]);
            final minuto = int.parse(finParts[1]);

            final finClase = DateTime(
              ahora.year,
              ahora.month,
              ahora.day,
              hora,
              minuto,
            );

            // Avisar 5 minutos antes del final de la clase
            final momentoSalida = finClase.subtract(const Duration(minutes: 5));

            if (momentoSalida.isAfter(ahora)) {
              await _programarAlarma(
                id: (horario.id * 10) + 2,
                fechaHora: momentoSalida,
                titulo: '⏰ Fin de Clase Próximo',
                cuerpo:
                    'La clase de ${horario.materia} está por concluir. Recuerda marcar tu salida.',
                payload: 'salida_${horario.id}',
              );
            }
          }
        } catch (e) {
          debugPrint('[NotificationService] Error calculando salida: $e');
        }
      }
    }
  }

  Future<void> _programarAlarma({
    required int id,
    required DateTime fechaHora,
    required String titulo,
    required String cuerpo,
    String? payload,
  }) async {
    try {
      final tzDateTime = tz.TZDateTime.from(fechaHora, tz.local);

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: titulo,
        body: cuerpo,
        scheduledDate: tzDateTime,
        notificationDetails: _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      debugPrint(
          '[NotificationService] Notificación programada ID $id a las $fechaHora: "$titulo"');
    } catch (e) {
      debugPrint('[NotificationService] Error en zonedSchedule: $e');
    }
  }

  /// Cancela la notificación de entrada de un horario cuando ya fue marcado
  Future<void> cancelarNotificacionEntrada(int horarioId) async {
    try {
      await _notificationsPlugin.cancel(id: (horarioId * 10) + 1);
    } catch (_) {}
  }

  /// Cancela la notificación de salida de un horario cuando ya fue marcado
  Future<void> cancelarNotificacionSalida(int horarioId) async {
    try {
      await _notificationsPlugin.cancel(id: (horarioId * 10) + 2);
    } catch (_) {}
  }

  /// Cancela todas las notificaciones pendientes
  Future<void> cancelarTodas() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }
}
