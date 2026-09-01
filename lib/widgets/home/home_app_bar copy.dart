// widgets/home/home_app_bar.dart
import 'package:flutter/material.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onRegistroFacial;
  final VoidCallback onHistorial;
  final VoidCallback onPerfil;
  final VoidCallback onLogout;
  final VoidCallback? onHelp;

  const HomeAppBar({
    super.key,
    required this.onRegistroFacial,
    required this.onHistorial,
    required this.onPerfil,
    required this.onLogout,
    this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text(
        'Control Docente',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Color(0xFF2D3436),
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF2D3436),
      elevation: 0,
      centerTitle: true,
      actions: [
        // Botón de ayuda (solo si onHelp no es null)
        if (onHelp != null)
          IconButton(
            onPressed: onHelp,
            icon: Icon(
              Icons.help_outline_rounded,
              color: Colors.grey.shade600,
              size: 24,
            ),
          ),
        // Botón de registro facial
        IconButton(
          onPressed: onRegistroFacial,
          icon: Icon(
            Icons.face_rounded,
            color: const Color(0xFF5B67CA),
            size: 24,
          ),
          tooltip: 'Registro Facial',
        ),
        // Botón de historial
        IconButton(
          onPressed: onHistorial,
          icon: Icon(
            Icons.history_rounded,
            color: Colors.grey.shade700,
            size: 24,
          ),
          tooltip: 'Historial',
        ),
        // Botón de perfil
        IconButton(
          onPressed: onPerfil,
          icon: Icon(
            Icons.person_rounded,
            color: Colors.grey.shade700,
            size: 24,
          ),
          tooltip: 'Perfil',
        ),
        // Botón de logout
        IconButton(
          onPressed: onLogout,
          icon: Icon(
            Icons.logout_rounded,
            color: Colors.red.shade400,
            size: 24,
          ),
          tooltip: 'Cerrar sesión',
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
