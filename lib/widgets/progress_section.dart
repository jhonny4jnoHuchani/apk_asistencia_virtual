// widgets/progress_section.dart
import 'package:flutter/material.dart';

class ProgressSection extends StatelessWidget {
  final int capturasRealizadas;
  final int totalCapturas;
  final int posicionActual;
  final int totalPosiciones;
  final int calidadPromedio;

  const ProgressSection({
    super.key,
    required this.capturasRealizadas,
    required this.totalCapturas,
    required this.posicionActual,
    required this.totalPosiciones,
    required this.calidadPromedio,
  });

  @override
  Widget build(BuildContext context) {
    final prog = capturasRealizadas / totalCapturas;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.timeline, color: Colors.deepPurple[300], size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Progreso',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                '$capturasRealizadas / $totalCapturas',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: prog,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                prog >= 0.8
                    ? Colors.green.shade500
                    : Colors.deepPurple.shade500,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fase ${posicionActual + 1} de $totalPosiciones',
                style: TextStyle(
                  color: Colors.deepPurple[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (calidadPromedio > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: calidadPromedio > 70
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        calidadPromedio > 70 ? Icons.star : Icons.star_half,
                        size: 12,
                        color:
                            calidadPromedio > 70 ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Calidad $calidadPromedio%',
                        style: TextStyle(
                          color: calidadPromedio > 70
                              ? Colors.green
                              : Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
