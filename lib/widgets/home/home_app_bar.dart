import 'dart:ui';
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

  // Colores estilo iOS moderno
  static const Color _primaryBlue = Color(0xFF007AFF);
  static const Color _primaryPurple = Color(0xFF5856D6);
  static const Color _successGreen = Color(0xFF34C759);
  static const Color _warningOrange = Color(0xFFFF9500);
  static const Color _dangerRed = Color(0xFFFF3B30);
  static const Color _iosGray = Color(0xFF8E8E93);
  static const Color _iosLightGray = Color(0xFFF2F2F7);
  static const Color _textPrimary = Color(0xFF1C1C1E);
  static const Color _textSecondary = Color(0xFF3C3C43);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: _textPrimary,
      elevation: 0,
      centerTitle: false,
      title: _buildTitle(),
      actions: _buildActions(context),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(
          height: 0.5,
          color: const Color(0xFFE5E5EA),
        ),
      ),
    );
  }

  // ==================== TITLE ====================
  Widget _buildTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAppLogo(),
        const SizedBox(width: 10),
        _buildAppTitle(),
      ],
    );
  }

  Widget _buildAppLogo() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryBlue, _primaryPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.fingerprint_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildAppTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Asistencia',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          'Control Biométrico',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 10,
            color: _iosGray,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ==================== ACTIONS ====================
  List<Widget> _buildActions(BuildContext context) {
    return [
      // Registro Facial
      // _buildActionButton(
      //   icon: Icons.face_rounded,
      //   onPressed: onRegistroFacial,
      //   tooltip: 'Registro Facial',
      //   color: _primaryBlue,
      //   showBadge: false,
      // ),
      // const SizedBox(width: 2),

      // Historial
      _buildActionButton(
        icon: Icons.history_rounded,
        onPressed: onHistorial,
        tooltip: 'Historial',
        color: _primaryPurple,
        showBadge: false,
      ),
      const SizedBox(width: 2),

      // Perfil
      _buildActionButton(
        icon: Icons.person_rounded,
        onPressed: onPerfil,
        tooltip: 'Perfil',
        color: _successGreen,
        showBadge: false,
      ),
      const SizedBox(width: 2),

      // Ayuda (nuevo)
      // _buildActionButton(
      //   icon: Icons.help_rounded,
      //   onPressed: onHelp ?? () => _showComingSoon(context),
      //   tooltip: 'Ayuda',
      //   color: _warningOrange,
      //   showBadge: true,
      //   comingSoon: true,
      // ),
      // const SizedBox(width: 2),

      // Cerrar Sesión
      _buildActionButton(
        icon: Icons.logout_rounded,
        onPressed: onLogout,
        tooltip: 'Cerrar sesión',
        color: _dangerRed,
        showBadge: false,
        isDanger: true,
      ),
      const SizedBox(width: 4),
    ];
  }

  // ==================== BOTON ACCIÓN ====================
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required Color color,
    bool showBadge = false,
    bool comingSoon = false,
    bool isDanger = false,
  }) {
    return Tooltip(
      message: comingSoon ? '$tooltip (Próximamente)' : tooltip,
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(12),
              splashColor: color.withOpacity(0.15),
              highlightColor: color.withOpacity(0.08),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDanger
                        ? color.withOpacity(0.3)
                        : color.withOpacity(0.15),
                    width: 1,
                  ),
                  color: isDanger
                      ? color.withOpacity(0.05)
                      : color.withOpacity(0.04),
                ),
                child: Icon(
                  icon,
                  color: isDanger ? color : color,
                  size: 22,
                ),
              ),
            ),
          ),
          // Badge de "Próximamente"
          if (comingSoon)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: _warningOrange,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  '!',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          // Badge de notificación
          if (showBadge && !comingSoon)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _dangerRed,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== DIÁLOGO "PRÓXIMAMENTE" ====================
  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.construction_rounded, color: _warningOrange, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Próximamente',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        content: const Text(
          'Esta funcionalidad estará disponible pronto.\n'
          'Estamos trabajando para ofrecerte la mejor experiencia.',
          style: TextStyle(
            fontSize: 14,
            color: _textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Entendido',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 0.5);
}
