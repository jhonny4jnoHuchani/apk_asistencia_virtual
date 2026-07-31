import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'cambio_password_screen.dart';
import 'registro_facial_screen.dart';
import 'login_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().actualizarPerfil();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        centerTitle: true,
      ),
      body: Consumer<AuthProvider>(

        builder: (context, authProvider, _) {
          final user = authProvider.user;
          

          print('DEBUG PERFIL: registroFacialCompleto=${authProvider.registroFacialCompleto}, embeddings=${authProvider.embeddingsCount}');


          if (user == null) {
            return const Center(child: Text('No hay información de usuario'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Avatar
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    _getInitials(user.nombreCompleto),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
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
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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

                const SizedBox(height: 30),

                // Tarjeta de información
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                              ? 'Completado ✅'
                              : 'Pendiente ⚠️',
                          valueColor: authProvider.registroFacialCompleto
                              ? Colors.green
                              : Colors.orange,
                        ),
                        if (!authProvider.registroFacialCompleto) ...[
                          const SizedBox(height: 8),
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
                ),

                const SizedBox(height: 20),

                // Acciones
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
            ),
          );
        },
      ),
    );
  }

  // ============================================
  // WIDGETS AUXILIARES
  // ============================================

  // Fila de información
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
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
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Botón de acción
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
            side: BorderSide(color: color.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  // Obtener iniciales del nombre
  String _getInitials(String nombre) {
    final partes = nombre.split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return nombre[0].toUpperCase();
  }

  // Cerrar sesión
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
}