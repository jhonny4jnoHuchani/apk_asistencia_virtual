import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> authenticate() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck || !isSupported) {
        return false;
      }

      // SINTAXIS CORRECTA: sin 'options'
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Autentícate para continuar',
      );

      return authenticated;
    } catch (e) {
      print('Error en autenticación biométrica: $e');
      return false;
    }
  }

  Future<bool> checkBiometricAvailability() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      return canCheck && isSupported && availableBiometrics.isNotEmpty;
    } catch (e) {
      print('Error al verificar biometría: $e');
      return false;
    }
  }
}
