import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
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
      await _habilitarBiometria();
    } else {
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
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Confirma tu identidad para deshabilitar la biometría',
      );

      if (authenticated) {
        setState(() => _biometricEnabled = false);
        await _guardarPreferenciaBiometrica(false);
        _mostrarSnackBar(
            'Biometría deshabilitada correctamente', _successColor);
      } else {
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

  // ============================================
  // MÉTODOS PARA FOTO DE PERFIL (ESTILO WHATSAPP)
  // ============================================

  Future<void> _tomarFoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        await _actualizarFoto(File(image.path));
      }
    } catch (e) {
      _mostrarSnackBar('Error al tomar la foto: $e', _dangerColor);
    }
  }

  Future<void> _seleccionarFoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        await _actualizarFoto(File(image.path));
      }
    } catch (e) {
      _mostrarSnackBar('Error al seleccionar la foto: $e', _dangerColor);
    }
  }

  Future<void> _actualizarFoto(File imageFile) async {
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.updateProfilePhoto(imageFile);

      if (success && mounted) {
        _mostrarSnackBar('Foto de perfil actualizada', _successColor);
        setState(() {});
      } else if (mounted) {
        _mostrarSnackBar(
          authProvider.error ?? 'Error al actualizar la foto',
          _dangerColor,
        );
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnackBar('Error: $e', _dangerColor);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _eliminarFoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar foto'),
        content: const Text(
            '¿Estás seguro de que quieres eliminar tu foto de perfil?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        final authProvider = context.read<AuthProvider>();
        final success = await authProvider.deleteProfilePhoto();

        if (success && mounted) {
          _mostrarSnackBar('Foto eliminada correctamente', _successColor);
          setState(() {});
        } else if (mounted) {
          _mostrarSnackBar(
            authProvider.error ?? 'Error al eliminar la foto',
            _dangerColor,
          );
        }
      } catch (e) {
        if (mounted) {
          _mostrarSnackBar('Error: $e', _dangerColor);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _mostrarOpcionesFoto(BuildContext context) {
    final hasPhoto = context.read<AuthProvider>().user?.fotoPerfilUrl != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Foto de perfil',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildOptionSheet(
                        icon: Icons.camera_alt_rounded,
                        title: 'Tomar foto',
                        subtitle: 'Usar la cámara del dispositivo',
                        onTap: () {
                          Navigator.pop(context);
                          _tomarFoto();
                        },
                      ),
                      const Divider(height: 1),
                      _buildOptionSheet(
                        icon: Icons.photo_library_rounded,
                        title: 'Seleccionar de galería',
                        subtitle: 'Elegir una foto existente',
                        onTap: () {
                          Navigator.pop(context);
                          _seleccionarFoto();
                        },
                      ),
                      if (hasPhoto) ...[
                        const Divider(height: 1),
                        _buildOptionSheet(
                          icon: Icons.visibility_rounded,
                          title: 'Ver foto',
                          subtitle: 'Visualizar foto actual',
                          onTap: () {
                            Navigator.pop(context);
                            _mostrarFotoCompleta(context);
                          },
                        ),
                        const Divider(height: 1),
                        _buildOptionSheet(
                          icon: Icons.delete_rounded,
                          title: 'Eliminar foto',
                          subtitle: 'Quitar la foto de perfil',
                          isDestructive: true,
                          onTap: () {
                            Navigator.pop(context);
                            _eliminarFoto();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionSheet({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withOpacity(0.1)
                    : _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : _primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDestructive ? Colors.red : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarFotoCompleta(BuildContext context) {
    final photoUrl = context.read<AuthProvider>().user?.fotoPerfilUrl;

    if (photoUrl == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Foto de perfil',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Imagen
              Container(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    photoUrl,
                    height: MediaQuery.of(context).size.height * 0.5,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 300,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 300,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Error al cargar la imagen',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // BUILD
  // ============================================

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
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {
              _mostrarOpcionesFoto(context);
            },
          ),
        ],
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
                // HEADER CON FOTO DE PERFIL ESTILO WHATSAPP
                _buildHeaderWhatsApp(user, authProvider),
                const SizedBox(height: 24),
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

  // ============================================
  // HEADER ESTILO WHATSAPP
  // ============================================

  Widget _buildHeaderWhatsApp(dynamic user, AuthProvider authProvider) {
    final hasPhoto =
        user.fotoPerfilUrl != null && user.fotoPerfilUrl!.isNotEmpty;

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Foto de perfil con borde
            GestureDetector(
              onTap: () => _mostrarOpcionesFoto(context),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _primaryColor.withOpacity(0.3),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[200],
                  backgroundImage:
                      hasPhoto ? NetworkImage(user.fotoPerfilUrl!) : null,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : hasPhoto
                          ? null
                          : Text(
                              _getInitials(user.nombreCompleto),
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                ),
              ),
            ),

            // Botón de cámara flotante (estilo WhatsApp)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: _primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _mostrarOpcionesFoto(context),
                    borderRadius: BorderRadius.circular(30),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Nombre
        Text(
          user.nombreCompleto,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),

        // Email
        Text(
          user.email,
          style: const TextStyle(
            fontSize: 14,
            color: _textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Badge de rol
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

        // Texto "Toca para cambiar tu foto" (estilo WhatsApp)
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _mostrarOpcionesFoto(context),
          child: Text(
            hasPhoto ? 'Toca para cambiar tu foto' : 'Agregar foto de perfil',
            style: TextStyle(
              fontSize: 13,
              color: _primaryColor,
              fontWeight: FontWeight.w500,
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
