import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import 'cambio_password_screen.dart';
import 'registro_facial_screen.dart';
import 'login_screen.dart';
import 'guia_demo_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  bool _biometricEnabled = false;
  bool _isLoading = false;
  bool _isBiometricAvailable = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Clave para SharedPreferences
  static const String _biometricPrefKey = 'biometric_enabled';

  // Constantes de diseño
  static const Color _primaryColor = Color(0xFF5B67CA);
  static const Color _secondaryColor = Color(0xFF8B95E0);
  static const Color _backgroundColor = Color(0xFFF8F9FC);
  static const Color _textPrimary = Color(0xFF2D3436);
  static const Color _textSecondary = Color(0xFF636E72);
  static const Color _successColor = Color(0xFF00B894);
  static const Color _warningColor = Color(0xFFFDCB6E);
  static const Color _dangerColor = Color(0xFFE17055);
  static const Color _infoColor = Color(0xFF74B9FF);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().actualizarPerfil();
      _cargarEstadoBiometrico();
    });
  }

  Future<void> _cargarEstadoBiometrico() async {
    await _verificarDisponibilidadBiometrica();
    await _cargarPreferenciaBiometrica();
  }

  Future<void> _verificarDisponibilidadBiometrica() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final enrolled = await _localAuth.getAvailableBiometrics();

      if (mounted) {
        setState(() {
          _isBiometricAvailable =
              isAvailable && isDeviceSupported && enrolled.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error al verificar biometría: $e');
      if (mounted) {
        setState(() {
          _isBiometricAvailable = false;
        });
      }
    }
  }

  Future<void> _cargarPreferenciaBiometrica() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPreference = prefs.getBool(_biometricPrefKey);

      if (mounted) {
        setState(() {
          _biometricEnabled = savedPreference ?? false;
        });
      }
    } catch (e) {
      print('Error al cargar preferencia: $e');
      if (mounted) {
        setState(() {
          _biometricEnabled = false;
        });
      }
    }
  }

  Future<void> _guardarPreferenciaBiometrica(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricPrefKey, enabled);
    } catch (e) {
      print('Error al guardar preferencia biométrica: $e');
    }
  }

  // Método principal para alternar biometría
  Future<void> _toggleBiometria(bool value) async {
    if (value) {
      // Habilitar biometría
      await _habilitarBiometria();
    } else {
      // Deshabilitar biometría
      await _deshabilitarBiometria();
    }
  }

  Future<void> _habilitarBiometria() async {
    if (!_isBiometricAvailable) {
      _mostrarSnackBar(
        'Este dispositivo no soporta autenticación biométrica',
        _warningColor,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Autenticar para habilitar
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Confirma tu identidad para habilitar la biometría',
      );

      if (authenticated) {
        setState(() => _biometricEnabled = true);
        await _guardarPreferenciaBiometrica(true);
        _mostrarSnackBar('Biometría habilitada correctamente', _successColor);
      } else {
        setState(() => _biometricEnabled = false);
        await _guardarPreferenciaBiometrica(false);
        _mostrarSnackBar('No se pudo habilitar la biometría', _dangerColor);
      }
    } catch (e) {
      _mostrarSnackBar('Error al habilitar biometría: $e', _dangerColor);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deshabilitarBiometria() async {
    setState(() => _isLoading = true);

    try {
      // Autenticar para deshabilitar
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Confirma tu identidad para deshabilitar la biometría',
      );

      if (authenticated) {
        setState(() => _biometricEnabled = false);
        await _guardarPreferenciaBiometrica(false);
        _mostrarSnackBar(
            'Biometría deshabilitada correctamente', _successColor);
      } else {
        // Mantener el estado anterior
        setState(() => _biometricEnabled = true);
        _mostrarSnackBar('No se pudo deshabilitar la biometría', _dangerColor);
      }
    } catch (e) {
      setState(() => _biometricEnabled = true);
      _mostrarSnackBar('Error al deshabilitar biometría: $e', _dangerColor);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarSnackBar(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == _successColor
                  ? Icons.check_circle_rounded
                  : color == _warningColor
                      ? Icons.warning_rounded
                      : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Mi Perfil',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _textPrimary,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.user;

          if (user == null) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeader(user),
                const SizedBox(height: 20),
                _buildInfoCard(user, authProvider),
                const SizedBox(height: 20),
                _buildBiometricCard(),
                const SizedBox(height: 20),
                _buildSecuritySection(),
                const SizedBox(height: 20),
                _buildActionsSection(context),
                const SizedBox(height: 20),
                _buildActionButtons(context, authProvider),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(dynamic user) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 55,
            backgroundColor: Colors.transparent,
            child: Text(
              _getInitials(user.nombreCompleto),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.nombreCompleto,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primaryColor.withOpacity(0.1),
                _secondaryColor.withOpacity(0.1)
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            user.rol.toUpperCase(),
            style: const TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(dynamic user, AuthProvider authProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInfoRow(
              icon: Icons.email_rounded,
              label: 'Correo electrónico',
              value: user.email,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.badge_rounded,
              label: 'ID de docente',
              value: user.id.toString(),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.face_retouching_natural_rounded,
              label: 'Registro facial',
              value: authProvider.registroFacialCompleto
                  ? 'Completado'
                  : 'Pendiente',
              valueColor: authProvider.registroFacialCompleto
                  ? _successColor
                  : _warningColor,
              showIcon: true,
            ),
            if (!authProvider.registroFacialCompleto) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: authProvider.embeddingsCount / 50,
                  backgroundColor: Colors.grey.shade200,
                  color: _warningColor,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Progreso: ${authProvider.embeddingsCount} de 50 capturas',
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _biometricEnabled
              ? [
                  _successColor.withOpacity(0.1),
                  _successColor.withOpacity(0.05)
                ]
              : [
                  _warningColor.withOpacity(0.1),
                  _warningColor.withOpacity(0.05)
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _biometricEnabled
              ? _successColor.withOpacity(0.3)
              : _warningColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_biometricEnabled ? _successColor : _warningColor)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _biometricEnabled
                        ? Icons.fingerprint_rounded
                        : Icons.fingerprint_outlined,
                    size: 32,
                    color: _biometricEnabled ? _successColor : _warningColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Autenticación Biométrica',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _biometricEnabled
                            ? 'Protegido con huella digital'
                            : 'Habilita para mayor seguridad',
                        style: TextStyle(
                          fontSize: 14,
                          color: _biometricEnabled
                              ? _successColor
                              : _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _biometricEnabled
                              ? Icons.check_circle_rounded
                              : Icons.info_rounded,
                          size: 20,
                          color:
                              _biometricEnabled ? _successColor : _warningColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _biometricEnabled ? 'Habilitado' : 'Deshabilitado',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _biometricEnabled
                                ? _successColor
                                : _warningColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (_isLoading)
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _primaryColor),
                  )
                else
                  Switch(
                    value: _biometricEnabled,
                    onChanged: _isBiometricAvailable
                        ? (value) => _toggleBiometria(value)
                        : null,
                    activeColor: _successColor,
                    activeTrackColor: _successColor.withOpacity(0.3),
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.grey.shade300,
                  ),
              ],
            ),
            if (!_isBiometricAvailable) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _dangerColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: _dangerColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Este dispositivo no soporta autenticación biométrica',
                        style: TextStyle(fontSize: 13, color: _dangerColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.security_rounded,
                      color: _primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Seguridad',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.verified_user_rounded,
              label: 'Estado de seguridad',
              value: _biometricEnabled && _isBiometricAvailable
                  ? 'Protegido'
                  : 'Básico',
              valueColor: _biometricEnabled && _isBiometricAvailable
                  ? _successColor
                  : _warningColor,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.info_outline_rounded,
              label: 'Biometría disponible',
              value: _isBiometricAvailable ? 'Sí' : 'No',
              valueColor: _isBiometricAvailable ? _successColor : _dangerColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings_rounded,
                      color: _primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Opciones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildActionOption(
              icon: Icons.help_outline_rounded,
              label: 'Guía de uso',
              color: _infoColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GuiaDemoScreen()),
                );
              },
            ),
            const Divider(height: 24),
            _buildActionOption(
              icon: Icons.privacy_tip_rounded,
              label: 'Política de privacidad',
              color: _textSecondary,
              onTap: () {
                _mostrarDialogo(
                  context,
                  'Política de privacidad',
                  'Tu información personal está protegida conforme a las leyes de protección de datos. Los datos biométricos se almacenan de forma segura y solo se utilizan para verificar tu identidad en el sistema de asistencia.',
                );
              },
            ),
            const Divider(height: 24),
            _buildActionOption(
              icon: Icons.info_outline_rounded,
              label: 'Versión de la aplicación',
              color: _textSecondary,
              onTap: () {
                _mostrarDialogo(
                  context,
                  'Versión',
                  'Asistencia Docente v1.0.0\n\nSistema de control de asistencia con reconocimiento facial.',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AuthProvider authProvider) {
    return Column(
      children: [
        if (!authProvider.registroFacialCompleto)
          _buildActionButton(
            icon: Icons.face_retouching_natural_rounded,
            label: 'Completar Registro Facial',
            color: _warningColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegistroFacialScreen()),
              );
            },
          ),
        _buildActionButton(
          icon: Icons.lock_reset_rounded,
          label: 'Cambiar Contraseña',
          color: _primaryColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CambioPasswordScreen()),
            );
          },
        ),
        _buildActionButton(
          icon: Icons.logout_rounded,
          label: 'Cerrar Sesión',
          color: _dangerColor,
          onTap: () => _cerrarSesion(context),
        ),
      ],
    );
  }

  Widget _buildActionOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: _textPrimary,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool showIcon = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: _textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: valueColor ?? _textPrimary,
                    ),
                  ),
                  if (showIcon && value == 'Completado') ...[
                    const SizedBox(width: 4),
                    Icon(Icons.check_circle_rounded,
                        size: 16, color: _successColor),
                  ],
                  if (showIcon && value == 'Pendiente') ...[
                    const SizedBox(width: 4),
                    Icon(Icons.warning_rounded, size: 16, color: _warningColor),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String nombre) {
    final partes = nombre.split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: _dangerColor, size: 28),
            const SizedBox(width: 12),
            const Text('Cerrar sesión'),
          ],
        ),
        content: const Text('¿Estás seguro de cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _dangerColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      final authProvider = context.read<AuthProvider>();
      final navigator = Navigator.of(context);
      await authProvider.logout();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _mostrarDialogo(BuildContext context, String titulo, String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}
