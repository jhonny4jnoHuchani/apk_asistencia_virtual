// lib/models/user.dart

class User {
  final int id;
  final String nombreCompleto;
  final String email;
  final String rol;
  final String? ci;
  final bool primerLogin;
  final int embeddingsCount;
  final bool registroFacialCompleto;
  final String? fotoPerfil;
  final String? fotoPerfilUrl;

  User({
    required this.id,
    required this.nombreCompleto,
    required this.email,
    required this.rol,
    this.ci,
    required this.primerLogin,
    required this.embeddingsCount,
    required this.registroFacialCompleto,
    this.fotoPerfil,
    this.fotoPerfilUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    print('=== USER FROM JSON ===');
    print('JSON: $json');
    print('primer_login: ${json['primer_login']}');
    print('foto_perfil: ${json['foto_perfil']}');
    print('foto_perfil_url: ${json['foto_perfil_url']}');
    print('========================');

    return User(
      id: json['id'] ?? 0,
      nombreCompleto: json['nombre_completo'] ?? '',
      email: json['email'] ?? '',
      rol: json['rol'] ?? 'docente',
      ci: json['ci'],
      primerLogin: json['primer_login'] ?? true,
      embeddingsCount: json['embeddings_count'] ?? 0,
      registroFacialCompleto: json['registro_facial_completo'] ?? false,
      fotoPerfil: json['foto_perfil'],
      fotoPerfilUrl: json['foto_perfil_url'] ?? json['foto_perfil'],
    );
  }

  User copyWith({
    int? id,
    String? nombreCompleto,
    String? email,
    String? rol,
    String? ci,
    bool? primerLogin,
    int? embeddingsCount,
    bool? registroFacialCompleto,
    String? fotoPerfil,
    String? fotoPerfilUrl,
  }) {
    return User(
      id: id ?? this.id,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      email: email ?? this.email,
      rol: rol ?? this.rol,
      ci: ci ?? this.ci,
      primerLogin: primerLogin ?? this.primerLogin,
      embeddingsCount: embeddingsCount ?? this.embeddingsCount,
      registroFacialCompleto:
          registroFacialCompleto ?? this.registroFacialCompleto,
      fotoPerfil: fotoPerfil ?? this.fotoPerfil,
      fotoPerfilUrl: fotoPerfilUrl ?? this.fotoPerfilUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre_completo': nombreCompleto,
      'email': email,
      'rol': rol,
      'ci': ci,
      'primer_login': primerLogin,
      'embeddings_count': embeddingsCount,
      'registro_facial_completo': registroFacialCompleto,
      'foto_perfil': fotoPerfil,
      'foto_perfil_url': fotoPerfilUrl,
    };
  }
}
