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
  });

  factory Marcado.fromJson(Map<String, dynamic> json) {
    print('=== PARSING MARCADO ===');
    print('JSON recibido: $json');

    try {
      final horario = json['horario'];
      String materiaNombre = 'Sin materia';
      String paraleloNombre = 'Sin paralelo';
      String? ubicacionNombre;

      if (horario != null) {
        print('Horario encontrado');

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

      // 🔥 CORREGIDO: Parsear latitud y longitud
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

      // 🔥 CORREGIDO: Parsear minutos
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
      );

      print('Marcado parseado exitosamente:');
      print('  id: ${marcado.id}');
      print('  materia: ${marcado.materia}');
      print('  paralelo: ${marcado.paralelo}');
      print('  tipo: ${marcado.tipo}');
      print('  estado: ${marcado.estado}');
      print('===========================');

      return marcado;
    } catch (e) {
      print('ERROR al parsear Marcado: $e');
      print('JSON que causó el error: $json');
      rethrow;
    }
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
}
