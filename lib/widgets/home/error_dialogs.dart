import 'package:flutter/material.dart';

class ErrorDialogs {
  static const Color _primaryColor = Color(0xFF5B67CA);
  static const Color _warningColor = Color(0xFFFDCB6E);
  static const Color _dangerColor = Color(0xFFE17055);

  // ============================================
  // DIÁLOGO: GAFAS DETECTADAS
  // ============================================
  static void mostrarDialogoLentes(
    BuildContext context, {
    required VoidCallback onCancelar,
    required VoidCallback onReintentar,
  }) {
    _showBaseDialog(
      context: context,
      icon: Icons.visibility_off_rounded,
      iconColor: _warningColor,
      title: 'Gafas detectadas',
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quítate las gafas para continuar con la verificación.'),
          SizedBox(height: 12),
          Text(
            'Las gafas pueden interferir con el reconocimiento facial.',
            style: TextStyle(fontSize: 12, color: Colors.orange),
          ),
        ],
      ),
      onCancelar: onCancelar,
      onReintentar: onReintentar,
    );
  }

  // ============================================
  // DIÁLOGO: GESTO INCORRECTO
  // ============================================
  static void mostrarDialogoGestoIncorrecto(
    BuildContext context, {
    required String gestoSolicitado,
    required String Function(String) instruccionGesto,
    required VoidCallback onCancelar,
    required VoidCallback onReintentar,
  }) {
    _showBaseDialog(
      context: context,
      icon: Icons.pan_tool_rounded,
      iconColor: _warningColor,
      title: 'Gesto incorrecto',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('El gesto "$gestoSolicitado" no coincide con lo solicitado.'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _warningColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: _warningColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Realiza el gesto: ${instruccionGesto(gestoSolicitado)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: _warningColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      onCancelar: onCancelar,
      onReintentar: onReintentar,
    );
  }

  // ============================================
  // DIÁLOGO: SPOOFING
  // ============================================
  static void mostrarDialogoSpoofing(
    BuildContext context, {
    required VoidCallback onCancelar,
    required VoidCallback onReintentar,
  }) {
    _showBaseDialog(
      context: context,
      icon: Icons.warning_amber_rounded,
      iconColor: _dangerColor,
      title: 'Suplantación detectada',
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'El sistema ha detectado un posible intento de suplantación.',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 12),
          Text(
            'Asegúrate de estar frente a la cámara y no usar fotos.',
            style: TextStyle(fontSize: 13, color: Colors.orange),
          ),
        ],
      ),
      onCancelar: onCancelar,
      onReintentar: onReintentar,
    );
  }

  // ============================================
  // DIÁLOGO: ERROR GENÉRICO
  // ============================================
  static void mostrarDialogoError(
    BuildContext context, {
    required String mensaje,
    required VoidCallback onCancelar,
    required VoidCallback onReintentar,
  }) {
    _showBaseDialog(
      context: context,
      icon: Icons.error_outline_rounded,
      iconColor: _dangerColor,
      title: 'Error',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mensaje, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Puede intentar nuevamente o cancelar2',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      onCancelar: onCancelar,
      onReintentar: onReintentar,
    );
  }

  // ============================================
  // DIÁLOGO BASE (evita duplicar código)
  // ============================================
  static void _showBaseDialog({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget content,
    required VoidCallback onCancelar,
    required VoidCallback onReintentar,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: content,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Pequeño delay para que el diálogo cierre antes de reabrir cámara
              Future.delayed(
                const Duration(milliseconds: 200),
                onCancelar,
              );
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Future.delayed(
                const Duration(milliseconds: 200),
                onReintentar,
              );
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
