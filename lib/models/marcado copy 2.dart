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
  final String? horaInicio;
  final String? horaFin;
  final double? ubicacionLatitud;
  final double? ubicacionLongitud;
  final String? ubicacionNombre;

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
    this.ubicacionLatitud,
    this.ubicacionLongitud,
    this.ubicacionNombre,
  });

  // CORREGIDO: Factory constructor sin usar 'this'
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
      double? ubicacionLatitud;
      double? ubicacionLongitud;
      String? ubicacionNombreCompleto;

      if (horario != null) {
        print('Horario encontrado');

        if (horario['hora_inicio'] != null) {
          horaInicio = horario['hora_inicio'];
          print('Hora inicio: $horaInicio');
        }
        if (horario['hora_fin'] != null) {
          horaFin = horario['hora_fin'];
          print('Hora fin: $horaFin');
        }

        final ubicacionData = horario['ubicacion'];
        if (ubicacionData != null) {
          print('Ubicacion data encontrada: $ubicacionData');

          ubicacionNombre = ubicacionData['nombre_lugar'] ??
              ubicacionData['nombre'] ??
              ubicacionData['nombre_ubicacion'] ??
              null;
          print('Nombre ubicacion: $ubicacionNombre');

          String? coordenadasStr;

          if (ubicacionData['coordenadas'] != null) {
            coordenadasStr = ubicacionData['coordenadas'].toString();
          } else if (ubicacionData['coordenada'] != null) {
            coordenadasStr = ubicacionData['coordenada'].toString();
          } else if (ubicacionData['latitud'] != null &&
              ubicacionData['longitud'] != null) {
            try {
              ubicacionLatitud =
                  double.tryParse(ubicacionData['latitud'].toString());
              ubicacionLongitud =
                  double.tryParse(ubicacionData['longitud'].toString());
              print('📍 Latitud separada: $ubicacionLatitud');
              print('📍 Longitud separada: $ubicacionLongitud');
            } catch (e) {
              print('Error parseando lat/lng separados: $e');
            }
          }

          if (coordenadasStr != null && coordenadasStr.contains(',')) {
            try {
              final partes = coordenadasStr.split(',');
              if (partes.length >= 2) {
                final lat = double.tryParse(partes[0].trim());
                final lng = double.tryParse(partes[1].trim());
                if (lat != null && lng != null) {
                  ubicacionLatitud = lat;
                  ubicacionLongitud = lng;
                  print(
                      '📍 Coordenadas parseadas: $ubicacionLatitud, $ubicacionLongitud');
                }
              }
            } catch (e) {
              print('Error parseando coordenadas: $e');
            }
          }

          if (ubicacionLatitud == null && ubicacionLongitud == null) {
            if (ubicacionData['nombre_lugar'] != null) {
              ubicacionNombreCompleto = ubicacionData['nombre_lugar'];
            } else if (ubicacionData['nombre'] != null) {
              ubicacionNombreCompleto = ubicacionData['nombre'];
            } else if (coordenadasStr != null &&
                !coordenadasStr.contains(',')) {
              ubicacionNombreCompleto = coordenadasStr;
            }
          } else {
            final nombreLugar = ubicacionData['nombre_lugar'] ??
                ubicacionData['nombre'] ??
                'Ubicacion';
            ubicacionNombreCompleto =
                '${ubicacionLatitud?.toStringAsFixed(6)}, ${ubicacionLongitud?.toStringAsFixed(6)}, $nombreLugar';
          }
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
      } else {
        print('No hay horario en el JSON, usando datos planos');
        materiaNombre = json['materia'] ?? 'Sin materia';
        paraleloNombre = json['paralelo'] ?? 'Sin paralelo';
        ubicacionNombre = json['ubicacion_nombre'] ?? json['ubicacion'];
        horaInicio = json['hora_inicio'];
        horaFin = json['hora_fin'];

        if (json['ubicacion_latitud'] != null &&
            json['ubicacion_longitud'] != null) {
          ubicacionLatitud =
              double.tryParse(json['ubicacion_latitud'].toString());
          ubicacionLongitud =
              double.tryParse(json['ubicacion_longitud'].toString());
        }
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

      // CREAR EL OBJETO MARCADO
      final marcado = Marcado(
        id: json['id'] ?? 0,
        horarioId: json['horario_id'] ?? 0,
        fecha: fechaParsed,
        hora: json['hora_marcado'] ?? json['hora'] ?? '',
        tipo: json['tipo_marcado'] ?? json['tipo'] ?? '',
        materia: materiaNombre,
        paralelo: paraleloNombre,
        ubicacion:
            ubicacionNombreCompleto ?? ubicacionNombre ?? json['ubicacion'],
        estado: json['estado_asistencia'] ?? json['estado'] ?? 'puntual',
        latitud: latitud,
        longitud: longitud,
        estadoFacial: json['estado'],
        minutosRetraso: minutosRetraso,
        minutosAdelanto: minutosAdelanto,
        horaInicio: horaInicio,
        horaFin: horaFin,
        ubicacionLatitud: ubicacionLatitud,
        ubicacionLongitud: ubicacionLongitud,
        ubicacionNombre: ubicacionNombre,
      );

      print('Marcado parseado exitosamente:');
      print('  id: ${marcado.id}');
      print('  materia: ${marcado.materia}');
      print('  paralelo: ${marcado.paralelo}');
      print('  tipo: ${marcado.tipo}');
      print('  estado: ${marcado.estado}');
      print('  horaInicio: ${marcado.horaInicio}');
      print('  horaFin: ${marcado.horaFin}');
      print('  ubicacion: ${marcado.ubicacion}');
      print('  ubicacionLatitud: ${marcado.ubicacionLatitud}');
      print('  ubicacionLongitud: ${marcado.ubicacionLongitud}');
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
      'ubicacion_latitud': ubicacionLatitud,
      'ubicacion_longitud': ubicacionLongitud,
      'ubicacion_nombre': ubicacionNombre,
    };
  }

  // GETTERS
  bool get tieneCoordenadas =>
      ubicacionLatitud != null &&
      ubicacionLongitud != null &&
      ubicacionLatitud != 0.0 &&
      ubicacionLongitud != 0.0;

  String get ubicacionDisplay {
    if (ubicacionNombre != null && ubicacionNombre!.isNotEmpty) {
      return ubicacionNombre!;
    }
    if (ubicacion != null && ubicacion!.isNotEmpty) {
      return ubicacion!;
    }
    return 'Sin ubicacion';
  }

  String get ubicacionCoordenadasDisplay {
    if (tieneCoordenadas) {
      return '${ubicacionLatitud!.toStringAsFixed(6)}, ${ubicacionLongitud!.toStringAsFixed(6)}';
    }
    return 'Sin coordenadas';
  }

  String get ubicacionCompleta {
    if (tieneCoordenadas) {
      final nombre = ubicacionNombre ?? 'Ubicacion';
      return '$nombre (${ubicacionCoordenadasDisplay})';
    }
    return ubicacionDisplay;
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

  String get horaInicioDisplay => horaInicio ?? '--:--';
  String get horaFinDisplay => horaFin ?? '--:--';
  String get horarioCompleto => '${horaInicioDisplay} - ${horaFinDisplay}';

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

  String get estadoFormateado {
    if (esPuntual) return 'Puntual';
    if (esRetraso) return 'Retraso';
    if (esAdelanto) return 'Adelanto';
    return estado;
  }

  Color get estadoColor {
    if (esPuntual) return const Color(0xFF34C759);
    if (esRetraso) return const Color(0xFFFF9500);
    if (esAdelanto) return const Color(0xFFFF3B30);
    return const Color(0xFF8E8E93);
  }

  IconData get estadoIcon {
    if (esPuntual) return Icons.check_circle_rounded;
    if (esRetraso) return Icons.warning_amber_rounded;
    if (esAdelanto) return Icons.timer_rounded;
    return Icons.help_rounded;
  }

  String get diferenciaDisplay {
    final diff = diferenciaMinutos;
    if (diff == null) return '';
    if (diff == 0) return '';
    return diff > 0 ? '+$diff min' : '$diff min';
  }
}
