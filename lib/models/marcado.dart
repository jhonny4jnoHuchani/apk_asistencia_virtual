import 'package:flutter/material.dart';

class Marcado {
  final int id;
  final int horarioId;
  final DateTime fecha;
  final String hora;
  final String tipo;
  final String materia;
  final String paralelo;
  final String? ubicacion;
  final String estado;
  final double? latitud;
  final double? longitud;
  final String? estadoFacial;
  final int? minutosRetraso;
  final int? minutosAdelanto;
  // NUEVOS CAMPOS PARA EL HORARIO
  final String? horaInicio;
  final String? horaFin;

  Marcado({
    required this.id,
    required this.horarioId,
    required this.fecha,
    required this.hora,
    required this.tipo,
    required this.materia,
    required this.paralelo,
    this.ubicacion,
    required this.estado,
    this.latitud,
    this.longitud,
    this.estadoFacial,
    this.minutosRetraso,
    this.minutosAdelanto,
    this.horaInicio,
    this.horaFin,
  });

  factory Marcado.fromJson(Map<String, dynamic> json) {
    print('=== PARSING MARCADO ===');
    print('JSON recibido: $json');

    try {
      final horario = json['horario'];
      String materiaNombre = 'Sin materia';
      String paraleloNombre = 'Sin paralelo';
      String? ubicacionNombre;
      String? horaInicio;
      String? horaFin;

      if (horario != null) {
        print('Horario encontrado');

        // Obtener hora inicio y fin del horario
        if (horario['hora_inicio'] != null) {
          horaInicio = horario['hora_inicio'];
          print('Hora inicio: $horaInicio');
        }
        if (horario['hora_fin'] != null) {
          horaFin = horario['hora_fin'];
          print('Hora fin: $horaFin');
        }

        final paraleloMateria = horario['paralelo_materia'];
        if (paraleloMateria != null) {
          print('ParaleloMateria encontrado');

          final materiaData = paraleloMateria['materia'];
          if (materiaData != null) {
            materiaNombre = materiaData['nombre_materia'] ??
                materiaData['nombre'] ??
                'Sin materia';
            print('Materia: $materiaNombre');
          }

          final paraleloData = paraleloMateria['paralelo'];
          if (paraleloData != null) {
            paraleloNombre = paraleloData['paralelo'] ??
                paraleloData['nombre'] ??
                'Sin paralelo';
            print('Paralelo: $paraleloNombre');
          }
        }

        final ubicacionData = horario['ubicacion'];
        if (ubicacionData != null) {
          ubicacionNombre =
              ubicacionData['nombre_lugar'] ?? ubicacionData['nombre'] ?? null;
          print('Ubicacion: $ubicacionNombre');
        }
      } else {
        print('No hay horario en el JSON, usando datos planos');
        materiaNombre = json['materia'] ?? 'Sin materia';
        paraleloNombre = json['paralelo'] ?? 'Sin paralelo';
        ubicacionNombre = json['ubicacion_nombre'] ?? json['ubicacion'];
        horaInicio = json['hora_inicio'];
        horaFin = json['hora_fin'];
      }

      DateTime fechaParsed;
      try {
        fechaParsed = json['fecha'] != null
            ? DateTime.parse(json['fecha'])
            : DateTime.now();
      } catch (e) {
        print('Error parseando fecha: $e');
        fechaParsed = DateTime.now();
      }

      // Parsear latitud
      double? latitud;
      if (json['latitud'] != null) {
        final latitudValue = json['latitud'];
        if (latitudValue is double) {
          latitud = latitudValue;
        } else if (latitudValue is String) {
          latitud = double.tryParse(latitudValue);
        } else if (latitudValue is int) {
          latitud = latitudValue.toDouble();
        }
        print('Latitud parseada: $latitud');
      }

      // Parsear longitud
      double? longitud;
      if (json['longitud'] != null) {
        final longitudValue = json['longitud'];
        if (longitudValue is double) {
          longitud = longitudValue;
        } else if (longitudValue is String) {
          longitud = double.tryParse(longitudValue);
        } else if (longitudValue is int) {
          longitud = longitudValue.toDouble();
        }
        print('Longitud parseada: $longitud');
      }

      // Parsear minutos de retraso
      int? minutosRetraso;
      if (json['minutos_retraso'] != null) {
        final value = json['minutos_retraso'];
        if (value is int) {
          minutosRetraso = value;
        } else if (value is String) {
          final parsed = double.tryParse(value);
          minutosRetraso = parsed?.toInt();
        } else if (value is double) {
          minutosRetraso = value.toInt();
        }
        print('minutosRetraso: $minutosRetraso');
      }

      // Parsear minutos de adelanto
      int? minutosAdelanto;
      if (json['minutos_adelanto'] != null) {
        final value = json['minutos_adelanto'];
        if (value is int) {
          minutosAdelanto = value;
        } else if (value is String) {
          final parsed = double.tryParse(value);
          minutosAdelanto = parsed?.toInt();
        } else if (value is double) {
          minutosAdelanto = value.toInt();
        }
        print('minutosAdelanto: $minutosAdelanto');
      }

      final marcado = Marcado(
        id: json['id'] ?? 0,
        horarioId: json['horario_id'] ?? 0,
        fecha: fechaParsed,
        hora: json['hora_marcado'] ?? json['hora'] ?? '',
        tipo: json['tipo_marcado'] ?? json['tipo'] ?? '',
        materia: materiaNombre,
        paralelo: paraleloNombre,
        ubicacion: ubicacionNombre,
        estado: json['estado_asistencia'] ?? json['estado'] ?? 'puntual',
        latitud: latitud,
        longitud: longitud,
        estadoFacial: json['estado'],
        minutosRetraso: minutosRetraso,
        minutosAdelanto: minutosAdelanto,
        horaInicio: horaInicio,
        horaFin: horaFin,
      );

      print('Marcado parseado exitosamente:');
      print('  id: ${marcado.id}');
      print('  materia: ${marcado.materia}');
      print('  paralelo: ${marcado.paralelo}');
      print('  tipo: ${marcado.tipo}');
      print('  estado: ${marcado.estado}');
      print('  horaInicio: ${marcado.horaInicio}');
      print('  horaFin: ${marcado.horaFin}');
      print('===========================');

      return marcado;
    } catch (e) {
      print('ERROR al parsear Marcado: $e');
      print('JSON que causo el error: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'horario_id': horarioId,
      'fecha': fecha.toIso8601String(),
      'hora_marcado': hora,
      'tipo_marcado': tipo,
      'materia': materia,
      'paralelo': paralelo,
      'ubicacion': ubicacion,
      'estado_asistencia': estado,
      'latitud': latitud,
      'longitud': longitud,
      'estado_facial': estadoFacial,
      'minutos_retraso': minutosRetraso,
      'minutos_adelanto': minutosAdelanto,
      'hora_inicio': horaInicio,
      'hora_fin': horaFin,
    };
  }

  bool get esPuntual => estado.toLowerCase() == 'puntual';
  bool get esRetraso => estado.toLowerCase() == 'retraso';
  bool get esAdelanto => estado.toLowerCase() == 'adelanto';

  String get estadoAsistencia {
    if (esRetraso) {
      return 'Retraso ${minutosRetraso ?? 0} min';
    } else if (esAdelanto) {
      return 'Adelanto ${minutosAdelanto ?? 0} min';
    }
    return 'Puntual';
  }

  // Nuevos getters para el historial
  String get horaInicioDisplay => horaInicio ?? '--:--';
  String get horaFinDisplay => horaFin ?? '--:--';
  String get horarioCompleto => '${horaInicioDisplay} - ${horaFinDisplay}';

  // Calcular diferencia en minutos entre la hora real y la programada
  int? get diferenciaMinutos {
    if (horaInicio == null) return null;
    try {
      final horaRealParts = hora.split(':');
      final horaProgParts = horaInicio!.split(':');

      if (horaRealParts.length == 2 && horaProgParts.length == 2) {
        final realMinutos =
            int.parse(horaRealParts[0]) * 60 + int.parse(horaRealParts[1]);
        final progMinutos =
            int.parse(horaProgParts[0]) * 60 + int.parse(horaProgParts[1]);
        return realMinutos - progMinutos;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Obtener el estado con el formato adecuado
  String get estadoFormateado {
    if (esPuntual) return 'Puntual';
    if (esRetraso) return 'Retraso';
    if (esAdelanto) return 'Adelanto';
    return estado;
  }

  // Obtener el color del estado
  Color get estadoColor {
    if (esPuntual) return const Color(0xFF34C759); // Verde iOS
    if (esRetraso) return const Color(0xFFFF9500); // Naranja iOS
    if (esAdelanto) return const Color(0xFFFF3B30); // Rojo iOS
    return const Color(0xFF8E8E93); // Gris iOS
  }

  // Icono del estado
  IconData get estadoIcon {
    if (esPuntual) return Icons.check_circle_rounded;
    if (esRetraso) return Icons.warning_amber_rounded;
    if (esAdelanto) return Icons.timer_rounded;
    return Icons.help_rounded;
  }

  // Formatear diferencia para mostrar
  String get diferenciaDisplay {
    final diff = diferenciaMinutos;
    if (diff == null) return '';
    if (diff == 0) return '';
    return diff > 0 ? '+$diff min' : '$diff min';
  }
}
