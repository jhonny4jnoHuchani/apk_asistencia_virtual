import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;
  final String email;
  final bool fromRegistration;

  const ResetPasswordScreen({
    super.key,
    this.token = '',
    required this.email,
    this.fromRegistration = false,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _passwordReset = false;
  String? _error;
  double _passwordStrength = 0.0; // NUEVO

  static const Color _primaryColor = Color(0xFF6C63FF);
  static const Color _secondaryColor = Color(0xFF3B82F6);
  static const Color _darkColor = Color(0xFF1A1A2E);
  static const Color _successColor = Color(0xFF00B894);
  static const Color _errorColor = Color(0xFFE17055);

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordStrength); // NUEVO
  }

  void _updatePasswordStrength() {
    // NUEVO
    final password = _passwordController.text;
    double strength = 0;
    if (password.length >= 6) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.25;
    setState(() => _passwordStrength = strength);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _setPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.setPassword(
        newPassword: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _passwordReset = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = authProvider.error ?? 'Error al establecer la contraseña';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
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
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildFormCard(),
                const SizedBox(height: 12),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        widget.fromRegistration ? 'Crear Contraseña' : 'Restablecer Contraseña',
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 17, color: _darkColor),
      ),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: widget.fromRegistration
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _darkColor),
              onPressed: () => Navigator.pop(context),
            )
          : null,
    );
  }

  BoxDecoration _buildBackgroundDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFFEEF2FF), Colors.white],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        TweenAnimationBuilder(
          // NUEVO: Animación de entrada
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          builder: (_, double val, child) =>
              Transform.scale(scale: val, child: child),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_primaryColor, _secondaryColor]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Icon(
              widget.fromRegistration
                  ? Icons.password_rounded
                  : Icons.lock_reset_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          widget.fromRegistration ? 'Crear Contraseña' : 'Nueva Contraseña',
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: _darkColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            widget.fromRegistration
                ? 'Establece una contraseña segura para tu cuenta'
                : 'Ingresa tu nueva contraseña para restablecer el acceso',
            style: TextStyle(
                fontSize: 13.5, color: Colors.grey.shade600, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.email_rounded, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(widget.email,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500)),
            ],
          ),
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
              if (_passwordReset)
                _buildSuccessWidget()
              else ...[
                if (_error != null) _buildErrorWidget(),
                _buildRequirementsWidget(),
                const SizedBox(height: 12),
                _buildPasswordField(),
                const SizedBox(height: 6),
                _buildPasswordStrengthBar(), // NUEVO
                const SizedBox(height: 12),
                _buildConfirmPasswordField(),
                const SizedBox(height: 18),
                _buildSubmitButton(),
                const SizedBox(height: 8),
                if (!widget.fromRegistration) _buildBackButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthBar() {
    // NUEVO
    Color color = _passwordStrength < 0.5
        ? _errorColor
        : _passwordStrength < 0.75
            ? Colors.orange
            : _successColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _passwordStrength,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _passwordStrength < 0.5
              ? 'Débil'
              : _passwordStrength < 0.75
                  ? 'Media'
                  : 'Fuerte',
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600),
        )
      ],
    );
  }

  Widget _buildRequirementsWidget() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: _primaryColor),
            const SizedBox(width: 6),
            Text('Requisitos:',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                    fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          Wrap(spacing: 12, runSpacing: 2, children: [
            _buildRequirementItem('6+ caracteres'),
            _buildRequirementItem('1 Mayúscula'),
            _buildRequirementItem('1 Número'),
            _buildRequirementItem('1 Símbolo'), // AGREGADO
          ]),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle_rounded,
          size: 10, color: _primaryColor.withOpacity(0.5)),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
    ]);
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(fontSize: 15),
      textInputAction: TextInputAction.next,
      decoration: _inputDecoration(
          'Nueva contraseña',
          'Mínimo 6 caracteres',
          Icons.lock_outline_rounded,
          _obscurePassword,
          () => setState(() => _obscurePassword = !_obscurePassword)),
      validator: (value) {
        if (value == null || value.isEmpty)
          return 'Ingresa tu nueva contraseña';
        if (value.length < 6) return 'Mínimo 6 caracteres';
        if (!RegExp(r'[A-Z]').hasMatch(value))
          return 'Debe incluir una mayúscula';
        if (!RegExp(r'[0-9]').hasMatch(value)) return 'Debe incluir un número';
        if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value))
          return 'Debe incluir un símbolo';
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      style: const TextStyle(fontSize: 15),
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _setPassword(),
      decoration: _inputDecoration(
          'Confirmar contraseña',
          'Repite tu contraseña',
          Icons.lock_outline_rounded,
          _obscureConfirmPassword,
          () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword)),
      validator: (value) {
        if (value == null || value.isEmpty)
          return 'Confirma tu nueva contraseña';
        if (value != _passwordController.text)
          return 'Las contraseñas no coinciden';
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(String label, String hint, IconData icon,
      bool obscure, VoidCallback onToggle) {
    // HELPER
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      suffixIcon: IconButton(
          icon: Icon(
              obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: Colors.grey.shade500,
              size: 20),
          onPressed: onToggle),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      // NUEVO: Gradiente
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
        onPressed: _isLoading ? null : _setPassword,
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
            : Text(widget.fromRegistration ? 'Crear Contraseña' : 'Restablecer',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildBackButton() {
    return TextButton(
      onPressed: () => Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen())),
      child: Text('Volver al inicio de sesión',
          style: TextStyle(
              color: _primaryColor, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _errorColor.withOpacity(0.2))),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: _errorColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(_error!,
                style: TextStyle(color: _errorColor, fontSize: 13))),
      ]),
    );
  }

  Widget _buildSuccessWidget() {
    return TweenAnimationBuilder(
      // NUEVO: Animación
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
          Text(
              widget.fromRegistration
                  ? 'Contraseña creada'
                  : 'Contraseña actualizada',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _darkColor)),
          const SizedBox(height: 4),
          Text(
              widget.fromRegistration
                  ? 'Tu cuenta ha sido configurada correctamente.'
                  : 'Tu contraseña ha sido restablecida.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => widget.fromRegistration
                            ? const HomeScreen()
                            : const LoginScreen()));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11)),
              child: Text(
                  widget.fromRegistration ? 'Ir al Inicio' : 'Ir a Login',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
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
