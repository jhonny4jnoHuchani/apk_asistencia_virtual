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
  final double? ubicacionLatitud;
  final double? ubicacionLongitud;
  final String? ubicacionNombre;
  final List<Map<String, double>>? poligono; // ✅ NUEVO: Puntos del poligono

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
    this.ubicacionLatitud,
    this.ubicacionLongitud,
    this.ubicacionNombre,
    this.poligono,
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

    String? ubicacionNombre;
    double? ubicacionLatitud;
    double? ubicacionLongitud;
    String? ubicacionCompleta;
    List<Map<String, double>>? poligono;

    if (ubicacionData != null) {
      ubicacionNombre =
          ubicacionData['nombre_lugar'] ?? ubicacionData['nombre'] ?? null;

      // Obtener coordenadas
      String? coordenadasStr;
      if (ubicacionData['coordenadas'] != null) {
        coordenadasStr = ubicacionData['coordenadas'].toString();
      }

      // Parsear coordenadas "lat,lng"
      if (coordenadasStr != null && coordenadasStr.contains(',')) {
        try {
          final partes = coordenadasStr.split(',');
          if (partes.length >= 2) {
            final lat = double.tryParse(partes[0].trim());
            final lng = double.tryParse(partes[1].trim());
            if (lat != null && lng != null) {
              ubicacionLatitud = lat;
              ubicacionLongitud = lng;
            }
          }
        } catch (e) {
          // Error parseando coordenadas
        }
      }

      // ✅ OBTENER POLIGONO
      if (ubicacionData['poligono'] != null &&
          ubicacionData['poligono'] is List) {
        poligono = [];
        for (var punto in ubicacionData['poligono']) {
          final lat = double.tryParse(punto['lat']?.toString() ?? '0');
          final lng = double.tryParse(punto['lng']?.toString() ?? '0');
          if (lat != null && lng != null) {
            poligono!.add({'lat': lat, 'lng': lng});
          }
        }
      }

      // Construir ubicacion completa
      if (ubicacionLatitud != null && ubicacionLongitud != null) {
        final nombre = ubicacionNombre ?? 'Ubicacion';
        ubicacionCompleta =
            '${ubicacionLatitud.toStringAsFixed(6)}, ${ubicacionLongitud.toStringAsFixed(6)}, $nombre';
      } else {
        ubicacionCompleta = ubicacionNombre ?? json['ubicacion_nombre'];
      }
    }

    return Horario(
      id: json['id'] ?? 0,
      diaSemana: json['dia_semana'] ?? '',
      horaInicio: json['hora_inicio'] ?? '',
      horaFin: json['hora_fin'] ?? '',
      materia: materiaNombre,
      paralelo: paraleloNombre,
      ubicacion:
          ubicacionCompleta ?? ubicacionNombre ?? json['ubicacion_nombre'],
      paraleloMateriaId: json['paralelo_materia_id'] ?? 0,
      ubicacionId: json['ubicacion_id'] ?? 0,
      yaMarcoEntrada: json['ya_marco_entrada'] ?? false,
      yaMarcoSalida: json['ya_marco_salida'] ?? false,
      ubicacionLatitud: ubicacionLatitud,
      ubicacionLongitud: ubicacionLongitud,
      ubicacionNombre: ubicacionNombre,
      poligono: poligono,
    );
  }

  // Getters
  bool get tieneCoordenadas =>
      ubicacionLatitud != null &&
      ubicacionLongitud != null &&
      ubicacionLatitud != 0.0 &&
      ubicacionLongitud != 0.0;

  bool get tienePoligono => poligono != null && poligono!.length >= 3;

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
    double? ubicacionLatitud,
    double? ubicacionLongitud,
    String? ubicacionNombre,
    List<Map<String, double>>? poligono,
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
      ubicacionLatitud: ubicacionLatitud ?? this.ubicacionLatitud,
      ubicacionLongitud: ubicacionLongitud ?? this.ubicacionLongitud,
      ubicacionNombre: ubicacionNombre ?? this.ubicacionNombre,
      poligono: poligono ?? this.poligono,
    );
  }
}
