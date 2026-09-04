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

  // Constantes para colores (evita recrear objetos)
  static const _gradientColors = [
    Color(0xFF6C63FF),
    Color(0xFF00D4FF),
  ];

  static const _primaryColor = Color(0xFF6C63FF);
  static const _secondaryColor = Color(0xFF00D4FF);
  static const _dangerColor = Color(0xFFFF6B6B);
  static const _darkColor = Color(0xFF1A1A2E);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: _buildTitle(),
      backgroundColor: Colors.white,
      foregroundColor: _darkColor,
      elevation: 0,
      centerTitle: false,
      bottom: _buildBottomGradient(),
      actions: _buildActions(),
    );
  }

  // ==================== TITLE ====================
  Widget _buildTitle() {
    return Row(
      mainAxisSize:
          MainAxisSize.min, // Importante: no ocupa más espacio del necesario
      children: [
        _buildLogo(),
        const SizedBox(width: 12),
        _buildTitleText(),
      ],
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: _gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: _secondaryColor.withOpacity(0.2),
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
    );
  }

  Widget _buildTitleText() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: _gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: const Text(
        'Control Docente',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ==================== BOTTOM ====================
  PreferredSizeWidget _buildBottomGradient() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(2),
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              _primaryColor,
              _secondaryColor,
              _primaryColor,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.3),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTIONS ====================
  List<Widget> _buildActions() {
    return [
      // Botón de ayuda (descomentar si se necesita)
      // if (onHelp != null)
      //   _buildActionButton(
      //     icon: Icons.help_outline_rounded,
      //     onPressed: onHelp!,
      //     color: Colors.grey.shade400,
      //     tooltip: 'Ayuda',
      //     glowColor: Colors.grey.shade400,
      //   ),

      // Botón de registro facial (descomentar si se necesita)
      // _buildActionButton(
      //   icon: Icons.face_rounded,
      //   onPressed: onRegistroFacial,
      //   color: _primaryColor,
      //   tooltip: 'Registro Facial',
      //   glowColor: _primaryColor,
      //   isPrimary: true,
      // ),

      _buildActionButton(
        icon: Icons.history_rounded,
        onPressed: onHistorial,
        color: Colors.grey.shade600,
        tooltip: 'Historial',
        glowColor: _secondaryColor,
      ),
      _buildActionButton(
        icon: Icons.person_rounded,
        onPressed: onPerfil,
        color: Colors.grey.shade600,
        tooltip: 'Perfil',
        glowColor: _primaryColor,
      ),
      _buildActionButton(
        icon: Icons.logout_rounded,
        onPressed: onLogout,
        color: _dangerColor,
        tooltip: 'Cerrar sesión',
        glowColor: _dangerColor,
      ),
    ];
  }

  // ==================== ACTION BUTTON ====================
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
          icon: _buildButtonIcon(icon, color, isPrimary),
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
        ),
      ),
    );
  }

  Widget _buildButtonIcon(IconData icon, Color color, bool isPrimary) {
    return Container(
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
        color: color,
        size: isPrimary ? 22 : 20,
      ),
    );
  }

  // ==================== PREFERRED SIZE ====================
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 2);
}
