// lib/models/user.dart
class User {
  final int id;
  final String nombreCompleto;
  final String email;
  final String rol;
  final bool primerLogin; // ✅ Asegurar que el nombre sea correcto
  final int embeddingsCount;
  final bool registroFacialCompleto;

  User({
    required this.id,
    required this.nombreCompleto,
    required this.email,
    required this.rol,
    required this.primerLogin,
    required this.embeddingsCount,
    required this.registroFacialCompleto,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    print('=== USER FROM JSON ===');
    print('JSON: $json');
    print('primer_login: ${json['primer_login']}');
    print('========================');

    return User(
      id: json['id'] ?? 0,
      nombreCompleto: json['nombre_completo'] ?? '',
      email: json['email'] ?? '',
      rol: json['rol'] ?? 'docente',
      primerLogin: json['primer_login'] ?? true, // ✅ Mapear correctamente
      embeddingsCount: json['embeddings_count'] ?? 0,
      registroFacialCompleto: json['registro_facial_completo'] ?? false,
    );
  }
}
