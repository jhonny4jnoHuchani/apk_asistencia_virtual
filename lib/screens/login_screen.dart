import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import 'cambio_password_screen.dart';
import 'home_screen.dart';
import 'registro_facial_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isBiometricLoading = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Paleta de colores moderna y refinada
  static const Color primary = Color(0xFF1A1A2E);
  static const Color primaryLight = Color(0xFF2D2D44);
  static const Color secondary = Color(0xFF6C63FF);
  static const Color secondaryLight = Color(0xFF8B83FF);
  static const Color accent = Color(0xFF00D4FF);
  static const Color success = Color(0xFF00E676);
  static const Color background = Color(0xFFF5F7FA);
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color errorColor = Color(0xFFEF4444);

  // Colores neón para el logo
  static const Color neonCyan = Color(0xFF06D6A0);
  static const Color neonPurple = Color(0xFF7C3AED);
  static const Color neonPink = Color(0xFFEC4899);
  static const Color neonBlue = Color(0xFF3B82F6);

  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    _verificarBiometria();
    _cargarCredenciales();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _verificarBiometria() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final enrolled = await _localAuth.getAvailableBiometrics();

      setState(() {
        _biometricAvailable =
            isAvailable && isDeviceSupported && enrolled.isNotEmpty;
      });

      if (_biometricAvailable) {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('biometric_user_id');
        if (userId != null && userId.isNotEmpty) {
          setState(() {
            _biometricEnabled = true;
          });
        }
      }
    } catch (e) {
      setState(() {
        _biometricAvailable = false;
        _biometricEnabled = false;
      });
    }
  }

  Future<void> _cargarCredenciales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('remember_email');
      final password = prefs.getString('remember_password');
      final remember = prefs.getBool('remember_me') ?? false;

      if (remember && email != null && password != null) {
        setState(() {
          _emailController.text = email;
          _passwordController.text = password;
          _rememberMe = true;
        });
      }
    } catch (e) {
      // Ignorar errores
    }
  }

  Future<void> _guardarCredenciales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('remember_email', _emailController.text.trim());
        await prefs.setString('remember_password', _passwordController.text);
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('remember_email');
        await prefs.remove('remember_password');
        await prefs.setBool('remember_me', false);
      }
    } catch (e) {
      // Ignorar errores
    }
  }

  Future<void> _loginConBiometria() async {
    if (!_biometricAvailable || !_biometricEnabled) {
      _mostrarMensaje(
        'Biometría no disponible o no configurada',
        Colors.orange,
      );
      return;
    }

    setState(() => _isBiometricLoading = true);

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verifica tu identidad para iniciar sesión',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!mounted) {
        setState(() => _isBiometricLoading = false);
        return;
      }

      if (authenticated) {
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('biometric_email');
        final password = prefs.getString('biometric_password');

        if (email != null &&
            password != null &&
            email.isNotEmpty &&
            password.isNotEmpty) {
          _emailController.text = email;
          _passwordController.text = password;
          await _login();
        } else {
          setState(() => _isBiometricLoading = false);
          _mostrarMensaje(
            'No hay credenciales guardadas para biometría',
            Colors.orange,
          );
        }
      } else {
        setState(() => _isBiometricLoading = false);
        _mostrarMensaje(
          'Autenticación biométrica fallida',
          Colors.red,
        );
      }
    } catch (e) {
      setState(() => _isBiometricLoading = false);
      _mostrarMensaje(
        'Error al autenticar con biometría: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _isBiometricLoading = false);
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      await _guardarCredenciales();

      // Guardar credenciales para biometría si está habilitada
      if (_biometricEnabled) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('biometric_email', _emailController.text.trim());
        await prefs.setString('biometric_password', _passwordController.text);
        await prefs.setString(
            'biometric_user_id', authProvider.user?.id.toString() ?? '');
      }

      _navigateToNextScreen();
    } else {
      _mostrarMensaje(
          authProvider.error ?? 'Error al iniciar sesión', Colors.red);
    }
  }

  void _navigateToNextScreen() {
    final authProvider = context.read<AuthProvider>();

    if (authProvider.necesitaCambiarPassword) {
      // ← Aquí se evalúa
      // Abre CambioPasswordScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CambioPasswordScreen()),
      );
    } else if (authProvider.necesitaRegistroFacial) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegistroFacialScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _mostrarMensaje(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 0,
      ),
    );
  }

  void _irARecuperarPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ForgotPasswordScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── LOGO ────────────────────────────────────
                    _buildLogo(),
                    const SizedBox(height: 32),

                    // ─── TÍTULO Y SUBTÍTULO ─────────────────────
                    _buildHeader(),
                    const SizedBox(height: 40),

                    // ─── CARD DE LOGIN ──────────────────────────
                    _buildLoginCard(),
                    const SizedBox(height: 20),

                    // ─── OPCIONES ───────────────────────────────
                    _buildOptionsRow(),
                    const SizedBox(height: 28),

                    // ─── BOTÓN PRINCIPAL ────────────────────────
                    _buildLoginButton(),
                    const SizedBox(height: 16),

                    // ─── BOTÓN BIOMÉTRICO ──────────────────────
                    if (_biometricAvailable && _biometricEnabled)
                      _buildBiometricButton(),
                    const SizedBox(height: 20),

                    // ─── DIVIDER ────────────────────────────────
                    _buildDivider(),
                    const SizedBox(height: 20),

                    // ─── BOTONES SOCIALES ───────────────────────
                    _buildSocialButtons(),
                    const SizedBox(height: 28),

                    // ─── FOOTER ─────────────────────────────────
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── WIDGETS ────────────────────────────────────────────────

  Widget _buildLogo() {
    return Center(
      child: Hero(
        tag: 'logo',
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glow animado
            AnimatedContainer(
              duration: const Duration(seconds: 3),
              height: 130,
              width: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    neonPurple.withOpacity(0.15),
                    neonCyan.withOpacity(0.08),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
            // Círculo principal con gradiente
            Container(
              height: 96,
              width: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    neonCyan,
                    neonBlue,
                    neonPurple,
                    neonPink,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: neonCyan.withOpacity(0.3),
                    blurRadius: 35,
                    spreadRadius: 4,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: neonPurple.withOpacity(0.2),
                    blurRadius: 45,
                    spreadRadius: 8,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 42,
                    color: primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          '¡Bienvenido de vuelta!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Accede a tu cuenta para continuar',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: textSecondary,
            fontWeight: FontWeight.w400,
            height: 1.5,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.8),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildTextField(
            label: 'Correo electrónico',
            icon: Icons.email_outlined,
            controller: _emailController,
            hintText: 'tú@email.com',
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa tu correo electrónico';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Ingresa un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          _buildTextField(
            label: 'Contraseña',
            icon: Icons.lock_outlined,
            controller: _passwordController,
            hintText: '••••••••',
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: textSecondary,
                size: 22,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa tu contraseña';
              }
              if (value.length < 6) {
                return 'Mínimo 6 caracteres';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: textSecondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textPrimary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 16,
            color: textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: textHint,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: suffixIcon,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: secondary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: errorColor,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: background,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildOptionsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildRememberMe(),
        _buildForgotPassword(),
      ],
    );
  }

  Widget _buildRememberMe() {
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: _rememberMe,
            onChanged: (value) {
              setState(() => _rememberMe = value ?? false);
            },
            activeColor: secondary,
            checkColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            side: BorderSide(
              color: borderColor,
              width: 2,
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Recordarme',
          style: TextStyle(
            fontSize: 14,
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPassword() {
    return TextButton(
      onPressed: _irARecuperarPassword,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        '¿Olvidaste tu contraseña?',
        style: TextStyle(
          color: secondary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          disabledBackgroundColor: textHint.withOpacity(0.3),
        ),
        child: _isLoading
            ? SizedBox(
                height: 26,
                width: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.login_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Iniciar Sesión',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: _isBiometricLoading ? null : _loginConBiometria,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: secondary.withOpacity(0.3),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
        ),
        child: _isBiometricLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: secondary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Platform.isIOS ? Icons.face_rounded : Icons.fingerprint,
                    color: secondary,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    Platform.isIOS
                        ? 'Acceder con Face ID'
                        : 'Acceder con Huella',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1.5,
            color: borderColor,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'O continúa con',
            style: TextStyle(
              color: textSecondary.withOpacity(0.4),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1.5,
            color: borderColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildSocialButton(
            icon: _buildGoogleIcon(),
            label: 'Google',
            onPressed: () {
              _mostrarMensaje('Próximamente disponible', Colors.orange);
            },
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildSocialButton(
            icon: Icon(
              Platform.isIOS ? Icons.face_rounded : Icons.fingerprint,
              color: _biometricAvailable && _biometricEnabled
                  ? secondary
                  : textSecondary,
              size: 26,
            ),
            label: Platform.isIOS ? 'Face ID' : 'Huella',
            onPressed: _biometricAvailable && _biometricEnabled
                ? _loginConBiometria
                : () {
                    _mostrarMensaje(
                      _biometricAvailable
                          ? 'Habilita la biometría en tu perfil primero'
                          : 'Tu dispositivo no soporta biometría',
                      Colors.orange,
                    );
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required Widget icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: borderColor,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4285F4),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'v3.0.0',
                style: TextStyle(
                  color: secondary.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: textSecondary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Secure Login',
              style: TextStyle(
                color: textSecondary.withOpacity(0.4),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: textSecondary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '2FA',
              style: TextStyle(
                color: secondary.withOpacity(0.4),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '© 2024 Asistencia Virtual Pro',
          style: TextStyle(
            color: textSecondary.withOpacity(0.15),
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
