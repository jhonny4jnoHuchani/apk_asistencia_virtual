import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();

  bool _isLoading = false;
  bool _emailSent = false;
  bool _showError = false;
  String? _errorMessage;

  int _resendTimer = 0;
  Timer? _timer;

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Regex compilado una vez - más rápido
  static final _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  static const Color _primaryColor = Color(0xFF6C63FF);
  static const Color _secondaryColor = Color(0xFF3B82F6);
  static const Color _darkColor = Color(0xFF1A1A2E);
  static const Color _successColor = Color(0xFF00B894);
  static const Color _errorColor = Color(0xFFE17055);

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _fadeAnim =
        CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryController, curve: Curves.easeOutCubic));
    _entryController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocus.dispose();
    _timer?.cancel();
    _entryController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendTimer = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_resendTimer <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendTimer = 0);
      } else {
        if (mounted) setState(() => _resendTimer--);
      }
    });
  }

  Future<void> _sendResetLink() async {
    // 1. Validación síncrona primero - 0ms
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }
    if (_isLoading) return; // evita doble tap

    // 2. Captura datos ANTES del setState para no leer controller en async gap
    final email = _emailController.text.trim().toLowerCase();
    final authProvider = context.read<AuthProvider>();

    // 3. UI inmediata - sin esperar nada
    setState(() {
      _isLoading = true;
      _showError = false;
      _errorMessage = null;
    });
    // Unfocus y haptic en background, no bloquean
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(HapticFeedback.mediumImpact());

    try {
      // Timeout de 12s para no quedarse colgado
      final success = await authProvider
          .sendPasswordResetLink(email)
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (success) {
        setState(() {
          _emailSent = true;
          _isLoading = false;
        });
        _startResendTimer();
      } else {
        setState(() {
          _isLoading = false;
          _showError = true;
          _errorMessage = authProvider.error ??
              'Error al enviar el correo. Intenta nuevamente.';
        });
        unawaited(HapticFeedback.heavyImpact());
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _showError = true;
        _errorMessage =
            'Tarda demasiado. Revisa tu conexión e intenta de nuevo.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _showError = true;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      unawaited(HapticFeedback.heavyImpact());
    }
  }

  // EL RESTO DE TU BUILD ES EXACTAMENTE IGUAL - LO DEJO INTACTO PARA MANTENER TAMAÑO Y ANIMACIONES
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Container(
        decoration: _buildBackgroundDecoration(),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    _buildIconHeader(),
                    const SizedBox(height: 20),
                    _buildHeaderText(),
                    const SizedBox(height: 24),
                    _buildFormCard(),
                    const SizedBox(height: 14),
                    _buildFooter(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Recuperar Contraseña',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: _darkColor,
              letterSpacing: -0.2)),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: _darkColor),
    );
  }

  BoxDecoration _buildBackgroundDecoration() {
    return const BoxDecoration(
      gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEEF2FF), Color(0xFFF7F8FC), Colors.white],
          stops: [0.0, 0.45, 1.0]),
    );
  }

  Widget _buildIconHeader() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.elasticOut,
        builder: (_, val, child) => Transform.scale(scale: val, child: child),
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryColor, _secondaryColor]),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: _primaryColor.withOpacity(0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 10)),
              BoxShadow(
                  color: _secondaryColor.withOpacity(0.20),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: const Icon(Icons.lock_reset_rounded,
              color: Colors.white, size: 36),
        ),
      ),
    );
  }

  Widget _buildHeaderText() {
    return Column(children: [
      const Text('¿Olvidaste tu contraseña?',
          style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: _darkColor,
              letterSpacing: -0.4),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
              'Ingresa tu correo y te enviaremos un enlace para restablecerla',
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade600, height: 1.5),
              textAlign: TextAlign.center)),
    ]);
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEF0F6), width: 1),
        boxShadow: [
          BoxShadow(
              color: _primaryColor.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8)),
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_emailSent)
                    _buildSuccessWidget()
                  else ...[
                    AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        child: _showError && _errorMessage != null
                            ? _buildErrorWidget()
                            : const SizedBox.shrink()),
                    _buildEmailField(),
                    const SizedBox(height: 20),
                    _buildSubmitButton(),
                    const SizedBox(height: 12),
                    _buildHelpText(),
                  ],
                ]),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      focusNode: _emailFocus,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.email],
      onFieldSubmitted: (_) => _sendResetLink(),
      decoration: InputDecoration(
        labelText: 'Correo electrónico',
        labelStyle: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500),
        floatingLabelStyle:
            const TextStyle(color: _primaryColor, fontWeight: FontWeight.w600),
        hintText: 'tú@email.com',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon:
            Icon(Icons.email_outlined, color: Colors.grey.shade500, size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primaryColor, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: _errorColor.withOpacity(0.6), width: 1)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _errorColor, width: 1.5)),
        filled: true,
        fillColor: const Color(0xFFF8F9FC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (value) {
        if (value == null || value.isEmpty)
          return 'Ingresa tu correo electrónico';
        if (!_emailRegex.hasMatch(value.trim()))
          return 'Ingresa un correo válido';
        return null;
      },
    );
  }

  Widget _buildSubmitButton() {
    final activo = !_isLoading;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: activo
                ? [_primaryColor, _secondaryColor]
                : [Colors.grey.shade300, Colors.grey.shade400]),
        boxShadow: activo
            ? [
                BoxShadow(
                    color: _primaryColor.withOpacity(0.32),
                    blurRadius: 12,
                    offset: const Offset(0, 6))
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: activo ? _sendResetLink : null,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : const Row(
                      key: ValueKey('content'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Icon(Icons.send_rounded,
                              size: 18, color: Colors.white),
                          SizedBox(width: 10),
                          Text('Enviar enlace',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.1)),
                        ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelpText() {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('¿Ya recordaste tu contraseña?',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Iniciar sesión',
                  style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
          ]),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF5F3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _errorColor.withOpacity(0.22))),
      child: Row(children: [
        Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
                color: _errorColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.error_outline_rounded,
                color: _errorColor, size: 16)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(_errorMessage!,
                style: const TextStyle(
                    color: _errorColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35))),
      ]),
    );
  }

  Widget _buildSuccessWidget() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (_, val, child) => Opacity(
          opacity: val,
          child: Transform.translate(
              offset: Offset(0, 24 * (1 - val)), child: child)),
      child: Column(children: [
        Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
                color: _successColor.withOpacity(0.10), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded,
                color: _successColor, size: 52)),
        const SizedBox(height: 16),
        const Text('¡Correo enviado!',
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _darkColor,
                letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text('Revisa tu bandeja de entrada',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5)),
        const SizedBox(height: 4),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F3F9),
                borderRadius: BorderRadius.circular(8)),
            child: Text(_emailController.text.trim(),
                style: const TextStyle(
                    color: _darkColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600))),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_primaryColor, _secondaryColor]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: _primaryColor.withOpacity(0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ]),
                  child: const Center(
                      child: Text('Ir al inicio de sesión',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)))),
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _resendTimer > 0
              ? Row(
                  key: ValueKey('timer_$_resendTimer'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                      Icon(Icons.hourglass_bottom_rounded,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 5),
                      Text('Reenviar en ${_resendTimer}s',
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w500))
                    ])
              : TextButton.icon(
                  key: const ValueKey('resend_btn'),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _sendResetLink();
                  },
                  icon: const Icon(Icons.refresh_rounded,
                      size: 15, color: _primaryColor),
                  label: const Text('¿No llegó? Reenviar',
                      style: TextStyle(
                          color: _primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700))),
        ),
      ]),
    );
  }

  Widget _buildFooter() {
    return Center(
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.school_outlined,
                  size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 5),
              Text('Sistema de Asistencia Docente',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500))
            ])));
  }
}
