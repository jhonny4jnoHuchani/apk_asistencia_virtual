class Marcado {
  final int id;
  final DateTime fecha;
  final String hora;
  final String tipo; // 'entrada' o 'salida'
  final String materia;
  final String paralelo;
  final String estado; // 'puntual', 'retraso'
  final double? latitud;
  final double? longitud;

  Marcado({
    required this.id,
    required this.fecha,
    required this.hora,
    required this.tipo,
    required this.materia,
    required this.paralelo,
    required this.estado,
    this.latitud,
    this.longitud,
  });

  factory Marcado.fromJson(Map<String, dynamic> json) {
    return Marcado(
      id: json['id'] ?? 0,
      fecha: json['fecha'] != null 
          ? DateTime.parse(json['fecha']) 
          : DateTime.now(),
      hora: json['hora'] ?? '',
      tipo: json['tipo'] ?? '',
      materia: json['materia'] ?? '',
      paralelo: json['paralelo'] ?? '',
      estado: json['estado'] ?? 'puntual',
      latitud: json['latitud']?.toDouble(),
      longitud: json['longitud']?.toDouble(),
    );
  }

  // Color según estado
  bool get esPuntual => estado.toLowerCase() == 'puntual';
  bool get esRetraso => estado.toLowerCase() == 'retraso';
}