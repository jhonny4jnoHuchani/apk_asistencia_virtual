import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/horario.dart';
import '../models/clase_semanal.dart';

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

  // Avisos semanales que se repiten solos: Android los dispara aunque la app
  // este cerrada y los reprograma despues de reiniciar el celular.
  // Los IDs semanales empiezan en 100000 para no chocar con el aviso de
  // prueba (mostrarNotificacionInmediata).
  static const int _baseIdSemanal = 100000;

  /// Programa los avisos de toda la semana y ajusta los de hoy segun lo que
  /// ya se marco (si ya marco la salida, el aviso de hoy no llega).
  Future<void> programarNotificacionesSemana(
    List<ClaseSemanal> clases,
    List<Horario> horariosHoy,
  ) async {
    await init();

    // Cancelar los avisos semanales anteriores (por si cambio el horario)
    try {
      final pendientes =
          await _notificationsPlugin.pendingNotificationRequests();
      for (final p in pendientes) {
        if (p.id >= _baseIdSemanal) {
          await _notificationsPlugin.cancel(id: p.id);
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error cancelando semanales: $e');
    }

    final hoy = DateTime.now().weekday;

    for (final clase in clases) {
      if (!clase.estaActivo) continue;
      final dia = _numeroDia(clase.diaSemana);
      final inicio = _parseHora(clase.horaInicio);
      final fin = _parseHora(clase.horaFin);
      if (dia == null || inicio == null) continue;

      // Horario de hoy que corresponde a esta clase (si es hoy)
      Horario? deHoy;
      if (dia == hoy) {
        for (final h in horariosHoy) {
          if (_mismaHora(h.horaInicio, clase.horaInicio) &&
              _mismaHora(h.horaFin, clase.horaFin)) {
            deHoy = h;
            break;
          }
        }
      }

      // --- ENTRADA: 30 minutos antes del inicio (cuando se habilita) ---
      await _programarSemanal(
        id: _baseIdSemanal + (clase.id * 10) + 1,
        dia: dia,
        hora: inicio,
        antes: const Duration(minutes: 30),
        saltarHoy: deHoy?.yaMarcoEntrada ?? false,
        titulo: '🔔 ¡Marcado Habilitado!',
        cuerpo:
            'Ya puedes registrar tu entrada para ${clase.materia} (${clase.paralelo}).',
        payload: 'entrada_${clase.id}',
      );

      // --- SALIDA: 5 minutos antes del fin ---
      if (fin != null) {
        await _programarSemanal(
          id: _baseIdSemanal + (clase.id * 10) + 2,
          dia: dia,
          hora: fin,
          antes: const Duration(minutes: 5),
          saltarHoy: deHoy?.yaMarcoSalida ?? false,
          titulo: '⏰ Fin de Clase Próximo',
          cuerpo:
              'La clase de ${clase.materia} está por concluir. Recuerda marcar tu salida.',
          payload: 'salida_${clase.id}',
        );
      }
    }
  }

  /// Programa un aviso que se repite cada semana el mismo dia y hora.
  /// Si [saltarHoy] es true, la primera vez sera la proxima semana.
  Future<void> _programarSemanal({
    required int id,
    required int dia,
    required List<int> hora,
    required Duration antes,
    required bool saltarHoy,
    required String titulo,
    required String cuerpo,
    String? payload,
  }) async {
    try {
      final ahora = tz.TZDateTime.now(tz.local);
      final diasHasta = (dia - ahora.weekday + 7) % 7;
      final fechaClase = ahora.add(Duration(days: diasHasta));
      var clase = tz.TZDateTime(tz.local, fechaClase.year, fechaClase.month,
          fechaClase.day, hora[0], hora[1]);

      if (saltarHoy && diasHasta == 0) {
        clase = clase.add(const Duration(days: 7));
      }
      var aviso = clase.subtract(antes);
      while (!aviso.isAfter(ahora)) {
        aviso = aviso.add(const Duration(days: 7));
      }

      final androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final puedeExacta =
          await androidPlugin?.canScheduleExactNotifications() ?? true;

      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: titulo,
        body: cuerpo,
        scheduledDate: aviso,
        notificationDetails: _notificationDetails(),
        androidScheduleMode: puedeExacta
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        // Repetir cada semana el mismo dia y hora
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );

      debugPrint(
          '[NotificationService] Semanal ID $id desde $aviso: "$titulo"');
    } catch (e) {
      debugPrint('[NotificationService] Error en aviso semanal: $e');
    }
  }

  // "lunes" / "MIÉRCOLES" / "sabado" -> 1..7 (DateTime.monday = 1)
  static int? _numeroDia(String dia) {
    final d = dia
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e');
    const dias = {
      'lunes': DateTime.monday,
      'martes': DateTime.tuesday,
      'miercoles': DateTime.wednesday,
      'jueves': DateTime.thursday,
      'viernes': DateTime.friday,
      'sabado': DateTime.saturday,
      'domingo': DateTime.sunday,
    };
    return dias[d];
  }

  // "08:00" o "08:00:00" -> [8, 0]
  static List<int>? _parseHora(String hora) {
    final partes = hora.split(':');
    if (partes.length < 2) return null;
    final h = int.tryParse(partes[0].trim());
    final m = int.tryParse(partes[1].trim());
    if (h == null || m == null) return null;
    return [h, m];
  }

  static bool _mismaHora(String a, String b) {
    final ha = _parseHora(a);
    final hb = _parseHora(b);
    return ha != null && hb != null && ha[0] == hb[0] && ha[1] == hb[1];
  }

  /// Cancela todas las notificaciones pendientes
  Future<void> cancelarTodas() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }
}
