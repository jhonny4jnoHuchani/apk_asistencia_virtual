class Horario {
  final int id;
  final String horaInicio;
  final String horaFin;
  final String materia;
  final String paralelo;
  final String? ubicacion;
  final bool yaMarcoEntrada;
  final bool yaMarcoSalida;

  Horario({
    required this.id,
    required this.horaInicio,
    required this.horaFin,
    required this.materia,
    required this.paralelo,
    this.ubicacion,
    required this.yaMarcoEntrada,
    required this.yaMarcoSalida,
  });

  factory Horario.fromJson(Map<String, dynamic> json) {
    return Horario(
      id: json['id'] ?? 0,
      horaInicio: json['hora_inicio'] ?? '',
      horaFin: json['hora_fin'] ?? '',
      materia: json['paralelo_materia']?['materia']?['nombre_materia'] ?? '',
      paralelo: json['paralelo_materia']?['paralelo']?['paralelo'] ?? '',
      ubicacion: json['ubicacion']?['nombre_lugar'],
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
}