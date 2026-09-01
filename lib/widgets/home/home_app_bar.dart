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
      title: Row(
        children: [
          // Logo futurista con efecto glow
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6C63FF),
                  Color(0xFF00D4FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0xFF00D4FF).withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Título con efecto neón
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFF6C63FF),
                Color(0xFF00D4FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: const Text(
              'Control Docente',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1A2E),
      elevation: 0,
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF6C63FF),
                Color(0xFF00D4FF),
                Color(0xFF6C63FF),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Botón de ayuda
        // if (onHelp != null)
        //   _buildActionButton(
        //     icon: Icons.help_outline_rounded,
        //     onPressed: onHelp!,
        //     color: Colors.grey.shade400,
        //     tooltip: 'Ayuda',
        //     glowColor: Colors.grey.shade400,
        //   ),

        // Botón de registro facial - DESTACADO
        // _buildActionButton(
        //   icon: Icons.face_rounded,
        //   onPressed: onRegistroFacial,
        //   color: const Color(0xFF6C63FF),
        //   tooltip: 'Registro Facial',
        //   glowColor: const Color(0xFF6C63FF),
        //   isPrimary: true,
        // ),

        // Botón de historial
        _buildActionButton(
          icon: Icons.history_rounded,
          onPressed: onHistorial,
          color: Colors.grey.shade600,
          tooltip: 'Historial',
          glowColor: const Color(0xFF00D4FF),
        ),

        // Botón de perfil
        _buildActionButton(
          icon: Icons.person_rounded,
          onPressed: onPerfil,
          color: Colors.grey.shade600,
          tooltip: 'Perfil',
          glowColor: const Color(0xFF6C63FF),
        ),

        // Botón de logout
        _buildActionButton(
          icon: Icons.logout_rounded,
          onPressed: onLogout,
          color: const Color(0xFFFF6B6B),
          tooltip: 'Cerrar sesión',
          glowColor: const Color(0xFFFF6B6B),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    required String tooltip,
    required Color glowColor,
    bool isPrimary = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: glowColor.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: glowColor.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPrimary ? color.withOpacity(0.1) : Colors.transparent,
              border: isPrimary
                  ? null
                  : Border.all(
                      color: color.withOpacity(0.2),
                      width: 1.5,
                    ),
            ),
            child: Icon(
              icon,
              color: isPrimary ? color : color,
              size: isPrimary ? 22 : 20,
            ),
          ),
          tooltip: tooltip,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 2);
}
