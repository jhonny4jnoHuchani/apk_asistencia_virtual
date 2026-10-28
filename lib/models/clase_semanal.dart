// Una clase del horario semanal (GET /horarios/semanal).
// Separado de Horario para no cambiar el modelo que usa el marcado del dia.
// Los nombres de campo se leen con alternativas porque la respuesta trae
// materia, paralelo y ubicacion como objetos.
class ClaseSemanal {
  final int id;
  final String diaSemana;
  final String horaInicio;
  final String horaFin;
  final String materia;
  final String paralelo;
  final String? actividad;
  final String? ubicacionNombre;
  final String? ubicacionTipo;
  final String? estado;

  ClaseSemanal({
    required this.id,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    required this.materia,
    required this.paralelo,
    this.actividad,
    this.ubicacionNombre,
    this.ubicacionTipo,
    this.estado,
  });

  factory ClaseSemanal.fromJson(Map<String, dynamic> json, {String? dia}) {
    final paraleloMateria = json['paralelo_materia'];
    final materia = json['materia'] ??
        (paraleloMateria is Map ? paraleloMateria['materia'] : null);
    final paralelo = json['paralelo'] ??
        (paraleloMateria is Map ? paraleloMateria['paralelo'] : null);
    final ubicacion = json['ubicacion'];

    return ClaseSemanal(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      diaSemana: dia ?? _texto(json['dia_semana']) ?? '',
      horaInicio: _texto(json['hora_inicio']) ?? '',
      horaFin: _texto(json['hora_fin']) ?? '',
      materia: _texto(materia, ['nombre_materia', 'nombre', 'sigla']) ??
          'Sin materia',
      paralelo: _texto(paralelo, ['paralelo', 'nombre']) ?? '-',
      actividad: _texto(
        json['actividad'] ?? json['tipo_actividad'],
        ['nombre', 'nombre_actividad', 'descripcion', 'tipo'],
      ),
      ubicacionNombre: _texto(
        ubicacion ?? json['ubicacion_nombre'],
        ['nombre_lugar', 'nombre', 'aula'],
      ),
      ubicacionTipo: ubicacion is Map
          ? _texto(ubicacion['tipo'] ??
              ubicacion['tipo_ambiente'] ??
              ubicacion['ambiente'] ??
              ubicacion['descripcion'])
          : null,
      estado: _estado(json),
    );
  }

  // Texto de un valor: si es un objeto, el primer campo encontrado
  static String? _texto(dynamic valor, [List<String> claves = const []]) {
    if (valor == null) return null;
    if (valor is Map) {
      for (final clave in claves) {
        final texto = _texto(valor[clave]);
        if (texto != null) return texto;
      }
      return null;
    }
    final texto = valor.toString().trim();
    return texto.isEmpty ? null : texto;
  }

  // "activo" / true / 1 -> "Activo"
  static String? _estado(Map<String, dynamic> json) {
    final valor = json['estado'] ?? json['activo'];
    if (valor == null) return null;
    if (valor is bool) return valor ? 'Activo' : 'Inactivo';
    if (valor is num) return valor == 1 ? 'Activo' : 'Inactivo';
    final texto = valor.toString().trim();
    if (texto.isEmpty) return null;
    return texto[0].toUpperCase() + texto.substring(1).toLowerCase();
  }

  // "UTOI · Laboratorio"
  String? get ubicacionDisplay {
    final partes = [ubicacionNombre, ubicacionTipo]
        .whereType<String>()
        .toSet()
        .toList();
    return partes.isEmpty ? null : partes.join(' · ');
  }

  bool get estaActivo => estado == null || estado!.toLowerCase() == 'activo';
}
