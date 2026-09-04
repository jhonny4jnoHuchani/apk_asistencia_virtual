import 'package:flutter/material.dart';

class CompletedDialog extends StatelessWidget {
  final int calidadPromedio;
  final VoidCallback onPressed;
  final int capturasTotales;

  const CompletedDialog({
    super.key,
    required this.calidadPromedio,
    required this.onPressed,
    this.capturasTotales = 76,
  });

  Color _getColorByCalidad() {
    if (calidadPromedio >= 90) return Colors.green;
    if (calidadPromedio >= 70) return Colors.orange;
    return Colors.red;
  }

  String _getMensajeCalidad() {
    if (calidadPromedio >= 90) return 'Excelente';
    if (calidadPromedio >= 70) return 'Buena';
    return 'Regular';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorByCalidad();
    final size = MediaQuery.of(context).size;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        // <-- CLAVE: Limita la altura maxima
        constraints: BoxConstraints(
          maxHeight: size.height * 0.65, // Max 65% de la pantalla
          maxWidth: 400,
        ),
        child: SingleChildScrollView(
          // <-- Por si aun asi no cabe
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER COMPACTO
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  // Cambie a Row para ocupar menos alto
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '¡Registro Completado!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Rostro registrado exitosamente',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // CONTENIDO COMPACTO
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // STATS EN FILA MAS CHICAS
                    Row(
                      children: [
                        Expanded(
                          child: _StatCardCompact(
                            icon: Icons.camera_alt,
                            label: 'Capturas',
                            value: '$capturasTotales',
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCardCompact(
                            icon: Icons.verified,
                            label: 'Calidad',
                            value:
                                // '$calidadPromedio%',
                                '100',
                            color: color,
                            // subLabel: _getMensajeCalidad(),
                            subLabel: 'Excelente',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // INFO BOX MAS PEQUEÑO
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.green.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ya puedes marcar asistencia facial',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // BOTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                        ),
                        child: const Text(
                          'Ir al Inicio',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// WIDGET COMPACTO PARA LAS STATS
class _StatCardCompact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subLabel;

  const _StatCardCompact({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
          ),
          if (subLabel != null)
            Text(
              subLabel!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            )
        ],
      ),
    );
  }
}
