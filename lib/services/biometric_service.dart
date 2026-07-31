import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Verificar si el dispositivo tiene biometría
  Future<bool> isBiometricAvailable() async {
    try {
      final canAuthenticate = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canAuthenticate && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  // Autenticar con huella o Face ID
  Future<bool> authenticate() async {
    try {
      final isAvailable = await isBiometricAvailable();

      if (!isAvailable) {
        // Dispositivo sin biometría (ej: Galaxy J2)
        // Retornamos true para que continúe sin bloquear
        return true;
      }

      // Dispositivo con biometría (ej: Redmi 9 Pro)
      // La huella es OBLIGATORIA
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verifica tu identidad para marcar asistencia',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Permite PIN/patrón como respaldo
        ),
      );

      return authenticated;
    } catch (e) {
      return false;
    }
  }

  // Obtener tipos de biometría disponibles
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }
}