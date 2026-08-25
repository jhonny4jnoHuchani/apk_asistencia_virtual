// widgets/status_bar.dart
import 'package:flutter/material.dart';

class StatusBar extends StatelessWidget {
  final Map<String, dynamic> posicion;
  final bool isAutomaticMode;
  final bool isCapturing;
  final int capturasRealizadas;
  final int totalCapturas;

  const StatusBar({
    super.key,
    required this.posicion,
    required this.isAutomaticMode,
    required this.isCapturing,
    required this.capturasRealizadas,
    required this.totalCapturas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade400,
                    Colors.deepPurple.shade700
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                posicion['icono'] as IconData,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.volume_up,
                        color: Colors.deepPurple[400],
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        posicion['nombre']!.toUpperCase(),
                        style: TextStyle(
                          color: Colors.deepPurple[700],
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isAutomaticMode
                        ? 'Capturando... $capturasRealizadas/$totalCapturas'
                        : 'Listo para iniciar',
                    style: TextStyle(
                      color: isAutomaticMode
                          ? Colors.deepPurple.shade600
                          : Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isCapturing)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.red.shade500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
