class Horario {
  final int id;
  final String diaSemana;
  final String horaInicio;
  final String horaFin;
  final String materia;
  final String paralelo;
  final String? ubicacion;
  final int paraleloMateriaId;
  final int ubicacionId;
  final bool yaMarcoEntrada;
  final bool yaMarcoSalida;

  Horario({
    required this.id,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    required this.materia,
    required this.paralelo,
    this.ubicacion,
    required this.paraleloMateriaId,
    required this.ubicacionId,
    required this.yaMarcoEntrada,
    required this.yaMarcoSalida,
  });

  factory Horario.fromJson(Map<String, dynamic> json) {
    final paraleloMateria = json['paralelo_materia'];
    final materiaData =
        paraleloMateria != null ? paraleloMateria['materia'] : null;
    final paraleloData =
        paraleloMateria != null ? paraleloMateria['paralelo'] : null;
    final ubicacionData = json['ubicacion'];

    String materiaNombre = 'Sin materia';
    if (materiaData != null) {
      materiaNombre = materiaData['nombre_materia'] ??
          materiaData['nombre'] ??
          'Sin materia';
    } else {
      materiaNombre = json['materia'] ?? 'Sin materia';
    }

    String paraleloNombre = 'Sin paralelo';
    if (paraleloData != null) {
      paraleloNombre =
          paraleloData['paralelo'] ?? paraleloData['nombre'] ?? 'Sin paralelo';
    } else {
      paraleloNombre = json['paralelo'] ?? 'Sin paralelo';
    }

    String ubicacionNombre = json['ubicacion_nombre'] ??
        (ubicacionData != null ? ubicacionData['nombre_lugar'] : null) ??
        (ubicacionData != null ? ubicacionData['nombre'] : null);

    return Horario(
      id: json['id'] ?? 0,
      diaSemana: json['dia_semana'] ?? '',
      horaInicio: json['hora_inicio'] ?? '',
      horaFin: json['hora_fin'] ?? '',
      materia: materiaNombre,
      paralelo: paraleloNombre,
      ubicacion: ubicacionNombre,
      paraleloMateriaId: json['paralelo_materia_id'] ?? 0,
      ubicacionId: json['ubicacion_id'] ?? 0,
      yaMarcoEntrada: json['ya_marco_entrada'] ?? false,
      yaMarcoSalida: json['ya_marco_salida'] ?? false,
    );
  }

  String get estadoMarcado {
    if (yaMarcoEntrada && yaMarcoSalida) return 'Completado';
    if (yaMarcoEntrada && !yaMarcoSalida) return 'Marcar Salida';
    return 'Marcar Entrada';
  }

  bool get estaCompletado => yaMarcoEntrada && yaMarcoSalida;

  bool get puedeMarcarEntrada => !yaMarcoEntrada;

  bool get puedeMarcarSalida => yaMarcoEntrada && !yaMarcoSalida;

  Horario copyWith({
    int? id,
    String? diaSemana,
    String? horaInicio,
    String? horaFin,
    String? materia,
    String? paralelo,
    String? ubicacion,
    int? paraleloMateriaId,
    int? ubicacionId,
    bool? yaMarcoEntrada,
    bool? yaMarcoSalida,
  }) {
    return Horario(
      id: id ?? this.id,
      diaSemana: diaSemana ?? this.diaSemana,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      materia: materia ?? this.materia,
      paralelo: paralelo ?? this.paralelo,
      ubicacion: ubicacion ?? this.ubicacion,
      paraleloMateriaId: paraleloMateriaId ?? this.paraleloMateriaId,
      ubicacionId: ubicacionId ?? this.ubicacionId,
      yaMarcoEntrada: yaMarcoEntrada ?? this.yaMarcoEntrada,
      yaMarcoSalida: yaMarcoSalida ?? this.yaMarcoSalida,
    );
  }
}
