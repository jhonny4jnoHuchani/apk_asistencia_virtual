// lib/config/api_config.dart
class ApiConfig {
  // ============================================
  // URL BASE - Cambiar según entorno
  // ============================================
  // Emulador Android: 10.0.2.2
  // iOS Simulator:    127.0.0.1
  // Dispositivo real: IP de tu computadora (ej: 192.168.1.100)
  static const String baseUrl = 'http://172.20.0.24:8000/api';

  // ============================================
  // ENDPOINTS DE AUTENTICACIÓN
  // ============================================
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String cambiarPassword = '/auth/cambiar-password';
  static const String perfil = '/auth/perfil';

  static const String setPassword = '/auth/set-password';

  // ============================================
  // ENDPOINTS DE RECUPERACION (PUBLICOS)
  // ============================================
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // ============================================
  // ENDPOINTS DE HORARIOS
  // ============================================
  static const String horariosHoy = '/horarios/hoy';

  // ============================================
  // ENDPOINTS DE MARCADOS
  // ============================================
  static const String marcarEntrada = '/marcados/entrada';
  static const String marcarSalida = '/marcados/salida';
  static const String marcadosHoy = '/marcados/hoy';
  static const String historial = '/marcados/historial';

  // ============================================
  // ENDPOINTS DE RECONOCIMIENTO FACIAL
  // ============================================
  // Registrar embedding (captura para registro facial)
  static const String registrarEmbedding =
      '/reconocimiento/registrar-embedding';

  // Verificar rostro con gesto (dos fotos: frontal + gesto)
  static const String verificar = '/reconocimiento/verificar';

  // Verificar rostro con una sola foto (para marcado rápido)
  static const String verificarSimple = '/reconocimiento/verificar-simple';

  // Obtener posiciones disponibles para registro
  static const String posicionesReconocimiento = '/reconocimiento/posiciones';

  // Obtener estado del registro facial de un docente
  static String estadoReconocimiento(int docenteId) =>
      '/reconocimiento/estado/$docenteId';

  // Obtener estado del registro facial del docente autenticado
  static const String miEstadoReconocimiento = '/reconocimiento/mi-estado';

  // Eliminar embeddings de un docente (admin)
  static String eliminarEmbeddings(int docenteId) =>
      '/reconocimiento/eliminar-embeddings/$docenteId';

  // Obtener historial de verificaciones faciales
  static String historialVerificaciones(int docenteId) =>
      '/reconocimiento/historial/$docenteId';
}
