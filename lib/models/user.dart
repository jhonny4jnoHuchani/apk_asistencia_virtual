class User {
  final int id;
  final String nombreCompleto;
  final String email;
  final String rol;
  final bool primerLogin;
  final int embeddingsCount;
  final bool registroFacialCompleto;

  User({
    required this.id,
    required this.nombreCompleto,
    required this.email,
    required this.rol,
    required this.primerLogin,
    this.embeddingsCount = 0,
    this.registroFacialCompleto = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      nombreCompleto: json['nombre_completo'] ?? '',
      email: json['email'] ?? '',
      rol: json['rol'] ?? 'docente',
      primerLogin: json['primer_login'] ?? false,
      embeddingsCount: json['embeddings_count'] ?? 0,
      registroFacialCompleto: json['registro_facial_completo'] ?? false,
    );
  }
}