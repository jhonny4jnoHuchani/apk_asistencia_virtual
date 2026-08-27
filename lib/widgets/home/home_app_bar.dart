import 'package:flutter/material.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onHelp;
  final VoidCallback onRegistroFacial;
  final VoidCallback onHistorial;
  final VoidCallback onPerfil;
  final VoidCallback onLogout;

  const HomeAppBar({
    super.key,
    required this.onHelp,
    required this.onRegistroFacial,
    required this.onHistorial,
    required this.onPerfil,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text(
        'Mis Horarios',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF2D3436),
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF2D3436),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded),
          tooltip: 'Ver guía de uso',
          onPressed: onHelp,
        ),
        IconButton(
          icon: const Icon(Icons.face_retouching_natural_rounded),
          tooltip: 'Registro Facial',
          onPressed: onRegistroFacial,
        ),
        IconButton(
          icon: const Icon(Icons.history_rounded),
          tooltip: 'Historial',
          onPressed: onHistorial,
        ),
        IconButton(
          icon: const Icon(Icons.person_rounded),
          tooltip: 'Perfil',
          onPressed: onPerfil,
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded),
          tooltip: 'Cerrar sesión',
          onPressed: onLogout,
          color: Colors.red.shade400,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
