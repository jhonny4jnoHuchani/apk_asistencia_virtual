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
  // ============================================
  // CONTROLADORES Y ESTADO
  // ============================================
  final _formKey = GlobalKey<FormState>();
  final _actualController = TextEditingController();
  final _nuevaController = TextEditingController();
  final _confirmacionController = TextEditingController();
  
  bool _obscureActual = true;
  bool _obscureNueva = true;
  bool _obscureConfirmacion = true;

  // ============================================
  // CICLO DE VIDA
  // ============================================
  @override
  void dispose() {
    _actualController.dispose();
    _nuevaController.dispose();
    _confirmacionController.dispose();
    super.dispose();
  }

  // ============================================
  // MÉTODOS PRINCIPALES
  // ============================================
  
  // Enviar cambio de contraseña al backend
  Future<void> _cambiarPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.cambiarPassword(
      _actualController.text,
      _nuevaController.text,
      _confirmacionController.text,
    );

    if (!mounted) return;

    if (success) {
      _navigateToNextScreen();
    } else {
      _showError(authProvider.error ?? 'Error al cambiar contraseña');
    }
  }

  // Decidir a qué pantalla ir después
  void _navigateToNextScreen() {
    final authProvider = context.read<AuthProvider>();

    // Si aún no ha hecho el registro facial, va obligatorio
    if (authProvider.necesitaRegistroFacial) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegistroFacialScreen()),
      );
    } else {
      // Si ya tiene todo, va al home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  // Mostrar errores
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================
  // CONSTRUCCIÓN DE LA UI
  // ============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cambiar Contraseña'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mensaje informativo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Por seguridad, debes cambiar tu contraseña '
                          'la primera vez que inicias sesión.',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Contraseña actual
                TextFormField(
                  controller: _actualController,
                  obscureText: _obscureActual,
                  decoration: InputDecoration(
                    labelText: 'Contraseña actual',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureActual ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureActual = !_obscureActual;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese su contraseña actual';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Nueva contraseña
                TextFormField(
                  controller: _nuevaController,
                  obscureText: _obscureNueva,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNueva ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNueva = !_obscureNueva;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese la nueva contraseña';
                    }
                    if (value.length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirmar nueva contraseña
                TextFormField(
                  controller: _confirmacionController,
                  obscureText: _obscureConfirmacion,
                  decoration: InputDecoration(
                    labelText: 'Confirmar nueva contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmacion ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmacion = !_obscureConfirmacion;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirme la nueva contraseña';
                    }
                    if (value != _nuevaController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Botón de cambiar contraseña
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return ElevatedButton(
                      onPressed: auth.isLoading ? null : _cambiarPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Cambiar Contraseña',
                              style: TextStyle(fontSize: 16),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}