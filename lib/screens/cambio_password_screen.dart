import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'registro_facial_screen.dart';
import 'home_screen.dart';

class CambioPasswordScreen extends StatefulWidget {
  const CambioPasswordScreen({super.key});

  @override
  State<CambioPasswordScreen> createState() => _CambioPasswordScreenState();
}

class _CambioPasswordScreenState extends State<CambioPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _actualController = TextEditingController();
  final _nuevaController = TextEditingController();
  final _confirmacionController = TextEditingController();

  bool _obscureActual = true;
  bool _obscureNueva = true;
  bool _obscureConfirmacion = true;
  bool _isLoading = false;
  double _passwordStrength = 0.0; // NUEVO

  // Mismo system de colores que ResetPassword
  static const Color _primaryColor = Color(0xFF6C63FF);
  static const Color _secondaryColor = Color(0xFF3B82F6);
  static const Color _darkColor = Color(0xFF1A1A2E);
  static const Color _successColor = Color(0xFF00B894);
  static const Color _errorColor = Color(0xFFE17055);

  @override
  void initState() {
    super.initState();
    _nuevaController.addListener(_updatePasswordStrength);
  }

  void _updatePasswordStrength() {
    final password = _nuevaController.text;
    double strength = 0;
    if (password.length >= 6) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.25;
    setState(() => _passwordStrength = strength);
  }

  @override
  void dispose() {
    _actualController.dispose();
    _nuevaController.dispose();
    _confirmacionController.dispose();
    super.dispose();
  }

  Future<void> _cambiarPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.cambiarPassword(
      _actualController.text,
      _nuevaController.text,
      _confirmacionController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _mostrarMensaje('Contraseña actualizada correctamente', _successColor);
      _navigateToNextScreen();
    } else {
      _mostrarMensaje(
          authProvider.error ?? 'Error al cambiar contraseña', _errorColor);
    }
  }

  void _navigateToNextScreen() {
    final authProvider = context.read<AuthProvider>();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => authProvider.necesitaRegistroFacial
            ? const RegistroFacialScreen()
            : const HomeScreen(),
      ),
    );
  }

  void _mostrarMensaje(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
                color == _successColor
                    ? Icons.check_circle
                    : Icons.error_outline,
                color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Cambiar Contraseña',
            style: TextStyle(fontWeight: FontWeight.bold, color: _darkColor)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _darkColor),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFEEF2FF), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                  _buildPasswordFields(),
                  const SizedBox(height: 28),
                  _buildSubmitButton(),
                  const SizedBox(height: 16),
                  _buildSecurityFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        TweenAnimationBuilder(
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
            child: const Icon(Icons.lock_reset, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 14),
        const Text('Actualizar Contraseña',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: _darkColor)),
        const SizedBox(height: 6),
        Text('Ingresa tu contraseña actual y la nueva',
            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: _primaryColor, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Por seguridad, cambia tu contraseña periódicamente',
              style: TextStyle(
                  fontSize: 13,
                  color: _darkColor,
                  height: 1.4,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordFields() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _buildPasswordField(
              controller: _actualController,
              label: 'Contraseña actual',
              obscure: _obscureActual,
              onToggle: () => setState(() => _obscureActual = !_obscureActual),
              validator: (value) =>
                  value!.isEmpty ? 'Ingrese su contraseña actual' : null,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _nuevaController,
              label: 'Nueva contraseña',
              obscure: _obscureNueva,
              onToggle: () => setState(() => _obscureNueva = !_obscureNueva),
              validator: (value) {
                if (value!.isEmpty) return 'Ingrese la nueva contraseña';
                if (value.length < 6) return 'Mínimo 6 caracteres';
                if (!RegExp(r'[A-Z]').hasMatch(value))
                  return 'Debe incluir una mayúscula';
                if (!RegExp(r'[0-9]').hasMatch(value))
                  return 'Debe incluir un número';
                if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value))
                  return 'Debe incluir un símbolo';
                return null;
              },
            ),
            const SizedBox(height: 6),
            _buildPasswordStrengthBar(), // NUEVO
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _confirmacionController,
              label: 'Confirmar nueva contraseña',
              obscure: _obscureConfirmacion,
              onToggle: () =>
                  setState(() => _obscureConfirmacion = !_obscureConfirmacion),
              validator: (value) {
                if (value!.isEmpty) return 'Confirme la nueva contraseña';
                if (value != _nuevaController.text)
                  return 'Las contraseñas no coinciden';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthBar() {
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        prefixIcon: Icon(Icons.lock_outline_rounded,
            color: Colors.grey.shade500, size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        suffixIcon: IconButton(
          icon: Icon(
              obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: Colors.grey.shade500,
              size: 20),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildSubmitButton() {
    return Container(
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
        onPressed: _isLoading ? null : _cambiarPassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('Cambiar Contraseña',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }

  Widget _buildSecurityFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, color: Colors.grey.shade400, size: 16),
        const SizedBox(width: 8),
        Text('Tu información está segura',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ],
    );
  }
}
