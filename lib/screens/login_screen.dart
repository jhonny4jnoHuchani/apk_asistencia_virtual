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

  static const Color neonCyan = Color(0xFF06D6A0);
  static const Color neonPurple = Color(0xFF7C3AED);
  static const Color neonPink = Color(0xFFEC4899);
  static const Color neonBlue = Color(0xFF3B82F6);

  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _biometricPrefKey = 'biometric_enabled';
  static const String _biometricEmailKey = 'biometric_email';
  static const String _biometricPasswordKey = 'biometric_password';
  static const String _biometricUserIdKey = 'biometric_user_id';

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

      final biometricAvailable =
          isAvailable && isDeviceSupported && enrolled.isNotEmpty;

      final prefs = await SharedPreferences.getInstance();
      final biometricEnabled = prefs.getBool(_biometricPrefKey) ?? false;
      final hasCredentials = prefs.getString(_biometricEmailKey) != null &&
          prefs.getString(_biometricEmailKey)!.isNotEmpty;

      if (mounted) {
        setState(() {
          _biometricAvailable = biometricAvailable;
          _biometricEnabled =
              biometricAvailable && biometricEnabled && hasCredentials;
        });
      }
    } catch (e) {
      print('Error al verificar biometría: $e');
      if (mounted) {
        setState(() {
          _biometricAvailable = false;
          _biometricEnabled = false;
        });
      }
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
      print('Error al cargar credenciales: $e');
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
      print('Error al guardar credenciales: $e');
    }
  }

  Future<void> _guardarCredencialesBiometricas(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_biometricEmailKey, _emailController.text.trim());
      await prefs.setString(_biometricPasswordKey, _passwordController.text);
      await prefs.setString(_biometricUserIdKey, userId);
    } catch (e) {
      print('Error al guardar credenciales biométricas: $e');
    }
  }

  Future<void> _loginConBiometria() async {
    if (!_biometricAvailable) {
      _mostrarMensaje(
          'Biometria no disponible en este dispositivo', Colors.orange);
      return;
    }

    if (!_biometricEnabled) {
      _mostrarMensaje(
        'Habilita la biometria en tu perfil primero',
        Colors.orange,
      );
      return;
    }

    setState(() => _isBiometricLoading = true);

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Inicia sesion con tu huella digital',
      );

      if (!mounted) return;

      if (authenticated) {
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString(_biometricEmailKey);
        final password = prefs.getString(_biometricPasswordKey);

        if (email != null &&
            password != null &&
            email.isNotEmpty &&
            password.isNotEmpty) {
          _emailController.text = email;
          _passwordController.text = password;
          await _login(skipValidation: true);
        } else {
          setState(() => _isBiometricLoading = false);
          _mostrarMensaje(
            'No hay credenciales guardadas para biometria',
            Colors.orange,
          );
        }
      } else {
        setState(() => _isBiometricLoading = false);
        _mostrarMensaje('Autenticacion biometrica fallida', Colors.red);
      }
    } catch (e) {
      print('Error en autenticación biométrica: $e');
      setState(() => _isBiometricLoading = false);
      _mostrarMensaje('Error al autenticar con biometria', Colors.red);
    }
  }

  Future<void> _login({bool skipValidation = false}) async {
    if (!skipValidation && !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);
    setState(() => _isBiometricLoading = false);

    if (success) {
      await _guardarCredenciales();

      final prefs = await SharedPreferences.getInstance();
      final biometricEnabled = prefs.getBool(_biometricPrefKey) ?? false;

      if (biometricEnabled) {
        await _guardarCredencialesBiometricas(
          authProvider.user?.id.toString() ?? '',
        );
      }

      _navigateToNextScreen();
    } else {
      _mostrarMensaje(
        authProvider.error ?? 'Error al iniciar sesion',
        Colors.red,
      );
    }
  }

  void _navigateToNextScreen() {
    final authProvider = context.read<AuthProvider>();

    if (authProvider.necesitaCambiarPassword) {
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
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;
    final isMedium = screenWidth < 400;

    // Tamaños adaptativos
    final horizontalPadding = isSmall ? 16.0 : (isMedium ? 20.0 : 28.0);
    final logoSize = isSmall ? 72.0 : (isMedium ? 84.0 : 96.0);
    final iconSize = isSmall ? 32.0 : (isMedium ? 36.0 : 42.0);
    final titleSize = isSmall ? 24.0 : (isMedium ? 27.0 : 30.0);
    final subtitleSize = isSmall ? 13.0 : (isMedium ? 14.0 : 16.0);
    final cardPadding = isSmall ? 16.0 : (isMedium ? 22.0 : 28.0);
    final buttonHeight = isSmall ? 48.0 : (isMedium ? 52.0 : 58.0);
    final spacing = isSmall ? 12.0 : (isMedium ? 16.0 : 20.0);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: isSmall ? 12.0 : 20.0,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      kToolbarHeight -
                      40,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLogo(logoSize, iconSize),
                      SizedBox(height: isSmall ? 16.0 : 24.0),
                      _buildHeader(titleSize, subtitleSize),
                      SizedBox(height: isSmall ? 20.0 : 28.0),
                      _buildLoginCard(cardPadding, isSmall),
                      SizedBox(height: isSmall ? 10.0 : 16.0),
                      _buildOptionsRow(isSmall),
                      SizedBox(height: isSmall ? 16.0 : 20.0),
                      _buildLoginButton(buttonHeight, isSmall),
                      if (_biometricAvailable && _biometricEnabled) ...[
                        SizedBox(height: isSmall ? 10.0 : 14.0),
                        _buildBiometricButton(buttonHeight, isSmall),
                      ],
                      SizedBox(height: isSmall ? 16.0 : 20.0),
                      _buildDivider(isSmall),
                      SizedBox(height: isSmall ? 12.0 : 16.0),
                      if (_biometricAvailable && _biometricEnabled)
                        _buildGoogleButtonOnly(buttonHeight, isSmall)
                      else
                        _buildSocialButtons(buttonHeight, isSmall),
                      SizedBox(height: isSmall ? 16.0 : 20.0),
                      _buildFooter(isSmall),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== LOGO ====================
  Widget _buildLogo(double size, double iconSize) {
    return Center(
      child: Hero(
        tag: 'logo',
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(seconds: 3),
              height: size * 1.4,
              width: size * 1.4,
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
            Container(
              height: size,
              width: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [neonCyan, neonBlue, neonPurple, neonPink],
                ),
                boxShadow: [
                  BoxShadow(
                    color: neonCyan.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: neonPurple.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 6,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: iconSize,
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

  // ==================== HEADER ====================
  Widget _buildHeader(double titleSize, double subtitleSize) {
    return Column(
      children: [
        Text(
          'Bienvenido de vuelta!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.3,
            height: 1.2,
          ),
        ),
        SizedBox(height: titleSize * 0.3),
        Text(
          'Accede a tu cuenta para continuar',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: subtitleSize,
            color: textSecondary,
            fontWeight: FontWeight.w400,
            height: 1.4,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  // ==================== LOGIN CARD ====================
  // ==================== LOGIN CARD ====================
  Widget _buildLoginCard(double padding, bool isSmall) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          _buildCleanTextField(
            label: 'Correo electrónico',
            icon: Icons.alternate_email_rounded,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            isSmall: isSmall,
            validator: (value) {
              if (value == null || value.trim().isEmpty)
                return 'Ingresa tu correo electrónico';
              final emailRegex =
                  RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
              if (!emailRegex.hasMatch(value.trim()))
                return 'Ingresa un correo válido';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildCleanTextField(
            label: 'Contraseña',
            icon: Icons.lock_outline_rounded,
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _login(),
            isSmall: isSmall,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: textSecondary,
                  size: 20),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty)
                return 'Ingresa tu contraseña';
              if (value.length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),
        ],
      ),
    );
  }

// ==================== TEXT FIELD LIMPIO ====================
  Widget _buildCleanTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
    required bool isSmall,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: TextStyle(fontSize: isSmall ? 14.0 : 15.0, color: textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textSecondary, fontSize: 14),
        prefixIcon: Icon(icon, color: textSecondary, size: 20),
        suffixIcon: suffixIcon,
        hintText: label == 'Correo electrónico' ? 'tu@email.com' : null,
        hintStyle: TextStyle(color: textHint),
        filled: true,
        fillColor: const Color(0xFFFAFBFC), // Gris casi blanco
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: secondary, width: 1.5)), // Solo borde morado al enfocar
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: errorColor)),
      ),
      validator: validator,
    );
  }

  // ==================== OPTIONS ROW ====================
  Widget _buildOptionsRow(bool isSmall) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildRememberMe(isSmall),
        _buildForgotPassword(isSmall),
      ],
    );
  }

  Widget _buildRememberMe(bool isSmall) {
    return Row(
      children: [
        SizedBox(
          width: isSmall ? 18.0 : 22.0,
          height: isSmall ? 18.0 : 22.0,
          child: Checkbox(
            value: _rememberMe,
            onChanged: (value) {
              setState(() => _rememberMe = value ?? false);
            },
            activeColor: secondary,
            checkColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isSmall ? 4.0 : 6.0),
            ),
            side: BorderSide(color: borderColor, width: 1.5),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        SizedBox(width: isSmall ? 6.0 : 10.0),
        Text(
          'Recordarme',
          style: TextStyle(
            fontSize: isSmall ? 12.0 : 14.0,
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPassword(bool isSmall) {
    return TextButton(
      onPressed: _irARecuperarPassword,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'Olvidaste tu contraseña?',
        style: TextStyle(
          color: secondary,
          fontWeight: FontWeight.w600,
          fontSize: isSmall ? 12.0 : 14.0,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ==================== LOGIN BUTTON ====================
  Widget _buildLoginButton(double height, bool isSmall) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _login(),
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSmall ? 12.0 : 16.0),
          ),
          elevation: 0,
          disabledBackgroundColor: textHint.withOpacity(0.3),
        ),
        child: _isLoading
            ? SizedBox(
                height: isSmall ? 20.0 : 26.0,
                width: isSmall ? 20.0 : 26.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login_rounded,
                    size: isSmall ? 18.0 : 24.0,
                    color: Colors.white,
                  ),
                  SizedBox(width: isSmall ? 8.0 : 12.0),
                  Text(
                    'Iniciar Sesion',
                    style: TextStyle(
                      fontSize: isSmall ? 14.0 : 17.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ==================== BIOMETRIC BUTTON ====================
  Widget _buildBiometricButton(double height, bool isSmall) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: _isBiometricLoading ? null : _loginConBiometria,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: secondary.withOpacity(0.3), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSmall ? 12.0 : 16.0),
          ),
          backgroundColor: Colors.white,
        ),
        child: _isBiometricLoading
            ? SizedBox(
                height: isSmall ? 18.0 : 24.0,
                width: isSmall ? 18.0 : 24.0,
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
                    size: isSmall ? 20.0 : 26.0,
                  ),
                  SizedBox(width: isSmall ? 8.0 : 12.0),
                  Text(
                    Platform.isIOS
                        ? 'Acceder con Face ID'
                        : 'Acceder con Huella',
                    style: TextStyle(
                      fontSize: isSmall ? 13.0 : 15.0,
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

  // ==================== DIVIDER ====================
  Widget _buildDivider(bool isSmall) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: borderColor)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 12.0 : 20.0),
          child: Text(
            'O continua con',
            style: TextStyle(
              color: textSecondary.withOpacity(0.4),
              fontSize: isSmall ? 11.0 : 13.0,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: borderColor)),
      ],
    );
  }

  // ==================== GOOGLE BUTTON ONLY ====================
  Widget _buildGoogleButtonOnly(double height, bool isSmall) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          _mostrarMensaje('Proximamente disponible', Colors.orange);
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSmall ? 10.0 : 14.0),
          ),
          padding: EdgeInsets.symmetric(vertical: isSmall ? 4.0 : 8.0),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildGoogleIcon(isSmall),
            SizedBox(width: isSmall ? 6.0 : 10.0),
            Text(
              'Continuar con Google',
              style: TextStyle(
                fontSize: isSmall ? 12.0 : 14.0,
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

  // ==================== SOCIAL BUTTONS ====================
  Widget _buildSocialButtons(double height, bool isSmall) {
    return Row(
      children: [
        Expanded(
          child: _buildSocialButton(
            icon: _buildGoogleIcon(isSmall),
            label: 'Google',
            isSmall: isSmall,
            onPressed: () {
              _mostrarMensaje('Proximamente disponible', Colors.orange);
            },
          ),
        ),
        SizedBox(width: isSmall ? 10.0 : 14.0),
        Expanded(
          child: _buildSocialButton(
            icon: Icon(
              Icons.fingerprint,
              color: _biometricAvailable ? secondary : textSecondary,
              size: isSmall ? 20.0 : 26.0,
            ),
            label: 'Huella',
            isSmall: isSmall,
            onPressed: _biometricAvailable
                ? _loginConBiometria
                : () {
                    _mostrarMensaje(
                      _biometricAvailable
                          ? 'Habilita la biometria en tu perfil primero'
                          : 'Tu dispositivo no soporta biometria',
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
    required bool isSmall,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: isSmall ? 44.0 : 52.0,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSmall ? 10.0 : 14.0),
          ),
          padding: EdgeInsets.symmetric(vertical: isSmall ? 4.0 : 8.0),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            SizedBox(width: isSmall ? 6.0 : 10.0),
            Text(
              label,
              style: TextStyle(
                fontSize: isSmall ? 12.0 : 14.0,
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

  // ==================== GOOGLE ICON ====================
  Widget _buildGoogleIcon(bool isSmall) {
    return Container(
      width: isSmall ? 18.0 : 24.0,
      height: isSmall ? 18.0 : 24.0,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: isSmall ? 12.0 : 16.0,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4285F4),
          ),
        ),
      ),
    );
  }

  // ==================== FOOTER ====================
  Widget _buildFooter(bool isSmall) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'v3.0.0',
                style: TextStyle(
                  color: secondary.withOpacity(0.6),
                  fontSize: isSmall ? 9.0 : 11.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: textSecondary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Secure Login',
              style: TextStyle(
                color: textSecondary.withOpacity(0.4),
                fontSize: isSmall ? 10.0 : 12.0,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: textSecondary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '2FA',
              style: TextStyle(
                color: secondary.withOpacity(0.4),
                fontSize: isSmall ? 10.0 : 12.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '2026 Asistencia Virtual Pro',
          style: TextStyle(
            color: textSecondary.withOpacity(0.15),
            fontSize: isSmall ? 9.0 : 11.0,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
