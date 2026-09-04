import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // NUEVO
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  bool _showError = false;
  String? _errorMessage;

  // NUEVO: Para reenviar
  int _resendTimer = 0;
  Timer? _timer;

  static const Color _primaryColor = Color(0xFF6C63FF);
  static const Color _secondaryColor = Color(0xFF3B82F6);
  static const Color _darkColor = Color(0xFF1A1A2E);
  static const Color _successColor = Color(0xFF00B894);
  static const Color _errorColor = Color(0xFFE17055);

  @override
  void dispose() {
    _emailController.dispose();
    _timer?.cancel(); // NUEVO
    super.dispose();
  }

  void _startResendTimer() {
    // NUEVO
    setState(() => _resendTimer = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer == 0) {
        timer.cancel();
      } else {
        setState(() => _resendTimer--);
      }
    });
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _showError = false;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.sendPasswordResetLink(
        _emailController.text.trim().toLowerCase(), // MEJORADO
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _emailSent = true;
          _isLoading = false;
          _showError = false;
        });
        _startResendTimer(); // NUEVO
      } else {
        setState(() {
          _isLoading = false;
          _showError = true;
          _errorMessage = authProvider.error ??
              'Error al enviar el correo. Intenta nuevamente.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showError = true;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Container(
        decoration: _buildBackgroundDecoration(),
        child: SafeArea(
          child: SingleChildScrollView(
            // <-- ya tenias esto
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              // <-- QUITÉ ConstrainedBox y center
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20), // <-- Agrega espacio arriba
                _buildIconHeader(),
                const SizedBox(height: 16),
                _buildHeaderText(),
                const SizedBox(height: 20),
                _buildFormCard(),
                const SizedBox(height: 12),
                _buildFooter(),
                const SizedBox(height: 20), // <-- Espacio abajo para el teclado
              ],
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
              fontWeight: FontWeight.bold, fontSize: 17, color: _darkColor)),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: _darkColor),
    );
  }

  BoxDecoration _buildBackgroundDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFEEF2FF), Colors.white]),
    );
  }

  Widget _buildIconHeader() {
    return Center(
      child: TweenAnimationBuilder(
        // NUEVO: Animación
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        builder: (_, double val, child) =>
            Transform.scale(scale: val, child: child),
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            gradient:
                const LinearGradient(colors: [_primaryColor, _secondaryColor]),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: _primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8))
            ],
          ),
          child: const Icon(Icons.lock_reset_rounded,
              color: Colors.white, size: 32),
        ),
      ),
    );
  }

  Widget _buildHeaderText() {
    return Column(
      children: [
        const Text('¿Olvidaste tu contraseña?',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: _darkColor)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
              'Ingresa tu correo y te enviaremos un enlace para restablecerla',
              style: TextStyle(
                  fontSize: 13.5, color: Colors.grey.shade600, height: 1.4),
              textAlign: TextAlign.center),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_emailSent)
                _buildSuccessWidget()
              else ...[
                if (_showError && _errorMessage != null) _buildErrorWidget(),
                _buildEmailField(),
                const SizedBox(height: 18),
                _buildSubmitButton(),
                const SizedBox(height: 10),
                _buildHelpText(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(fontSize: 15),
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _sendResetLink(),
      decoration: InputDecoration(
        labelText: 'Correo electrónico',
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        hintText: 'tú@email.com',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon:
            Icon(Icons.email_outlined, color: Colors.grey.shade500, size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: (value) {
        if (value == null || value.isEmpty)
          return 'Ingresa tu correo electrónico';
        final emailRegex =
            RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
        if (!emailRegex.hasMatch(value.trim()))
          return 'Ingresa un correo válido';
        return null;
      },
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      // NUEVO: Gradiente igual a las otras
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(colors: [_primaryColor, _secondaryColor]),
        boxShadow: [
          BoxShadow(
              color: _primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _sendResetLink,
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.send_rounded, size: 18),
                SizedBox(width: 8),
                Text('Enviar enlace',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
      ),
    );
  }

  // ==================== HELP TEXT ====================
  Widget _buildHelpText() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        // <-- CAMBIO 1: Wrap en vez de Row
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '¿Ya recordaste tu contraseña?',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Iniciar sesión',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _errorColor.withOpacity(0.2))),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: _errorColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(_errorMessage!,
                style: TextStyle(color: _errorColor, fontSize: 13))),
      ]),
    );
  }

  Widget _buildSuccessWidget() {
    return TweenAnimationBuilder(
      // NUEVO: Animación de entrada
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (_, double val, child) => Opacity(
          opacity: val,
          child: Transform.translate(
              offset: Offset(0, 20 * (1 - val)), child: child)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.green.shade50,
              Colors.green.shade100.withOpacity(0.5)
            ]),
            borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Icon(Icons.check_circle_rounded, color: _successColor, size: 48),
          const SizedBox(height: 12),
          const Text('¡Correo enviado!',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _darkColor)),
          const SizedBox(height: 4),
          Text('Revisa tu bandeja de entrada: ${_emailController.text}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen())),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11)),
              child: const Text('Ir al inicio de sesión',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          _resendTimer > 0 // NUEVO: Botón reenviar con timer
              ? Text('Reenviar en ${_resendTimer}s',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12))
              : TextButton(
                  onPressed: _sendResetLink,
                  child: Text('¿No llegó? Reenviar',
                      style: TextStyle(
                          color: _primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
        ]),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Sistema de Asistencia Docente',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
      ),
    );
  }
}
