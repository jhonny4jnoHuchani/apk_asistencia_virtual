import 'dart:ui';
import 'package:flutter/material.dart';

class CustomSnackbar {
  // ============================================
  // API PÚBLICA  (por defecto: ARRIBA)
  // ============================================
  static void showError(BuildContext context, String message,
      {bool top = true}) {
    _show(
      context,
      message,
      tint: const Color(0xFFFF3B30), // iOS Red
      icon: Icons.error_outline_rounded,
      top: top,
    );
  }

  static void showSuccess(BuildContext context, String message,
      {bool top = true}) {
    _show(
      context,
      message,
      tint: const Color(0xFF34C759), // iOS Green
      icon: Icons.check_circle_outline_rounded,
      top: top,
    );
  }

  static void showInfo(BuildContext context, String message,
      {bool top = true}) {
    _show(
      context,
      message,
      tint: const Color(0xFF0A84FF), // iOS Blue
      icon: Icons.info_outline_rounded,
      top: top,
    );
  }

  static void showWarning(BuildContext context, String message,
      {bool top = true}) {
    _show(
      context,
      message,
      tint: const Color(0xFFFF9F0A), // iOS Orange
      icon: Icons.warning_amber_rounded,
      top: top,
    );
  }

  // ============================================
  // IMPLEMENTACIÓN
  // ============================================
  static void _show(
    BuildContext context,
    String message, {
    required Color tint,
    required IconData icon,
    bool top = true,
  }) {
    if (!context.mounted) return;

    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: _buildContent(message, tint, icon),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        margin: top
            ? EdgeInsets.only(
                top: topPadding + 8,
                left: 16,
                right: 16,
                bottom: mediaQuery.size.height - topPadding - 120,
              )
            : EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: bottomPadding + 12,
              ),
        duration: const Duration(seconds: 3),
        dismissDirection: top ? DismissDirection.up : DismissDirection.down,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
    );
  }

  static Widget _buildContent(
    String message,
    Color tint,
    IconData icon,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: tint.withOpacity(0.85),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: tint.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
