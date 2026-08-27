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
    final horario = json['horario'];
    String materiaNombre = 'Sin materia';
    String paraleloNombre = 'Sin paralelo';
    String? ubicacionNombre;

    if (horario != null) {
      final paraleloMateria = horario['paralelo_materia'];
      if (paraleloMateria != null) {
        final materiaData = paraleloMateria['materia'];
        if (materiaData != null) {
          materiaNombre = materiaData['nombre_materia'] ??
              materiaData['nombre'] ??
              'Sin materia';
        }
        final paraleloData = paraleloMateria['paralelo'];
        if (paraleloData != null) {
          paraleloNombre = paraleloData['paralelo'] ??
              paraleloData['nombre'] ??
              'Sin paralelo';
        }
      }
      final ubicacionData = horario['ubicacion'];
      if (ubicacionData != null) {
        ubicacionNombre =
            ubicacionData['nombre_lugar'] ?? ubicacionData['nombre'] ?? null;
      }
    }

    DateTime fechaParsed;
    try {
      fechaParsed = json['fecha'] != null
          ? DateTime.parse(json['fecha'])
          : DateTime.now();
    } catch (e) {
      fechaParsed = DateTime.now();
    }

    return Marcado(
      id: json['id'] ?? 0,
      horarioId: json['horario_id'] ?? 0,
      fecha: fechaParsed,
      hora: json['hora_marcado'] ?? json['hora'] ?? '',
      tipo: json['tipo_marcado'] ?? json['tipo'] ?? '',
      materia: materiaNombre,
      paralelo: paraleloNombre,
      ubicacion: ubicacionNombre,
      estado: json['estado_asistencia'] ?? json['estado'] ?? 'puntual',
      latitud: json['latitud']?.toDouble(),
      longitud: json['longitud']?.toDouble(),
      estadoFacial: json['estado'],
      minutosRetraso:
          json['minutos_retraso'] is int ? json['minutos_retraso'] : null,
      minutosAdelanto:
          json['minutos_adelanto'] is int ? json['minutos_adelanto'] : null,
    );
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
