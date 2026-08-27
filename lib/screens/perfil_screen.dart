import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().actualizarPerfil();
      _verificarEstadoBiometrico();
    });
  }

  Future<void> _verificarEstadoBiometrico() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final enrolled = await _localAuth.getAvailableBiometrics();

      setState(() {
        _isBiometricAvailable =
            isAvailable && isDeviceSupported && enrolled.isNotEmpty;
        _biometricEnabled = _isBiometricAvailable;
      });
    } catch (e) {
      setState(() {
        _isBiometricAvailable = false;
        _biometricEnabled = false;
      });
    }
  }

  Future<void> _habilitarBiometria() async {
    if (!_isBiometricAvailable) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Este dispositivo no soporta autenticación biométrica'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason:
            'Habilita la autenticación biométrica para acceder más rápido',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        setState(() {
          _biometricEnabled = true;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometría habilitada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _biometricEnabled = false;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo habilitar la biometría'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al habilitar biometría: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.user;

          if (user == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando información del usuario...'),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeader(user, authProvider),
                const SizedBox(height: 24),
                _buildInfoCard(user, authProvider),
                const SizedBox(height: 20),
                _buildBiometricCard(authProvider), // Biometría en el medio
                const SizedBox(height: 20),
                _buildSecuritySection(authProvider),
                const SizedBox(height: 20),
                _buildActionsSection(context),
                const SizedBox(height: 20),
                _buildActionButtons(context, authProvider),
                const SizedBox(height: 20),
                _buildBiometricFloatingButton(), // Botón flotante en el borde
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(dynamic user, AuthProvider authProvider) {
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.blue.shade100,
          child: Text(
            _getInitials(user.nombreCompleto),
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.nombreCompleto,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            user.rol.toUpperCase(),
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(dynamic user, AuthProvider authProvider) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(
              icon: Icons.email,
              label: 'Correo electrónico',
              value: user.email,
            ),
            const Divider(),
            _buildInfoRow(
              icon: Icons.badge,
              label: 'ID de docente',
              value: user.id.toString(),
            ),
            const Divider(),
            _buildInfoRow(
              icon: Icons.face,
              label: 'Registro facial',
              value: authProvider.registroFacialCompleto
                  ? 'Completado'
                  : 'Pendiente',
              valueColor: authProvider.registroFacialCompleto
                  ? Colors.green
                  : Colors.orange,
              showIcon: true,
            ),
            if (!authProvider.registroFacialCompleto) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: authProvider.embeddingsCount / 50,
                backgroundColor: Colors.grey.shade200,
                color: Colors.orange,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 4),
              Text(
                'Progreso: ${authProvider.embeddingsCount} de 50 capturas',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Tarjeta de biometría en el medio de la pantalla
  Widget _buildBiometricCard(AuthProvider authProvider) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      color: _biometricEnabled ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _biometricEnabled
                      ? Icons.fingerprint
                      : Icons.fingerprint_outlined,
                  size: 32,
                  color: _biometricEnabled ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Autenticación Biométrica',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _biometricEnabled
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                        ),
                      ),
                      Text(
                        _biometricEnabled
                            ? 'Protegido con huella o reconocimiento facial'
                            : 'Habilita para mayor seguridad',
                        style: TextStyle(
                          fontSize: 14,
                          color: _biometricEnabled
                              ? Colors.green.shade600
                              : Colors.orange.shade600,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _biometricEnabled
                          ? Colors.green.shade200
                          : Colors.orange.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _biometricEnabled
                              ? Icons.check_circle
                              : Icons.warning,
                          size: 20,
                          color: _biometricEnabled
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _biometricEnabled ? 'Habilitado' : 'Deshabilitado',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _biometricEnabled
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (_isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: _biometricEnabled,
                    onChanged: _isBiometricAvailable
                        ? (_) => _habilitarBiometria()
                        : null,
                    activeColor: Colors.green,
                    activeTrackColor: Colors.green.shade300,
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.grey.shade300,
                  ),
              ],
            ),
            if (!_isBiometricAvailable) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Este dispositivo no soporta autenticación biométrica',
                        style: TextStyle(fontSize: 12, color: Colors.red),
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

  Widget _buildSecuritySection(AuthProvider authProvider) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Seguridad',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.verified_user,
              label: 'Estado de seguridad',
              value: _biometricEnabled && _isBiometricAvailable
                  ? 'Protegido'
                  : 'Básico',
              valueColor: _biometricEnabled && _isBiometricAvailable
                  ? Colors.green
                  : Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.info_outline,
              label: 'Biometría disponible',
              value: _isBiometricAvailable ? 'Si' : 'No',
              valueColor: _isBiometricAvailable ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Opciones',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildActionOption(
              icon: Icons.help_outline,
              label: 'Guía de uso',
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GuiaDemoScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            _buildActionOption(
              icon: Icons.shield,
              label: 'Política de privacidad',
              color: Colors.grey,
              onTap: () {
                _mostrarDialogo(
                  context,
                  'Política de privacidad',
                  'Tu información personal está protegida conforme a las leyes de protección de datos. Los datos biométricos se almacenan de forma segura y solo se utilizan para verificar tu identidad en el sistema de asistencia.',
                );
              },
            ),
            const Divider(),
            _buildActionOption(
              icon: Icons.info_outline,
              label: 'Versión de la aplicación',
              color: Colors.grey,
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
            context,
            icon: Icons.face,
            label: 'Completar Registro Facial',
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RegistroFacialScreen(),
                ),
              );
            },
          ),
        _buildActionButton(
          context,
          icon: Icons.lock,
          label: 'Cambiar Contraseña',
          color: Colors.blue,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CambioPasswordScreen(),
              ),
            );
          },
        ),
        _buildActionButton(
          context,
          icon: Icons.logout,
          label: 'Cerrar Sesión',
          color: Colors.red,
          onTap: () => _cerrarSesion(context),
        ),
      ],
    );
  }

  // Botón flotante de biometría en el borde inferior
  Widget _buildBiometricFloatingButton() {
    if (!_isBiometricAvailable) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton.extended(
          onPressed: _habilitarBiometria,
          backgroundColor: _biometricEnabled ? Colors.green : Colors.blue,
          icon: Icon(
            _biometricEnabled ? Icons.fingerprint : Icons.fingerprint_outlined,
            color: Colors.white,
          ),
          label: Text(
            _biometricEnabled ? 'Biometría activa' : 'Activar biometría',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildActionOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool showIcon = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: valueColor,
                      ),
                    ),
                    if (showIcon && value == 'Completado')
                      const SizedBox(width: 4),
                    if (showIcon && value == 'Completado')
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                    if (showIcon && value == 'Pendiente')
                      Icon(Icons.warning, size: 16, color: Colors.orange),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, color: color),
          label: Text(
            label,
            style: TextStyle(color: color),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: color.withAlpha(128)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
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
    return nombre[0].toUpperCase();
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
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
