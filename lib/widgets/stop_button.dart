// widgets/stop_button.dart
import 'package:flutter/material.dart';

class StopButton extends StatelessWidget {
  final VoidCallback onPressed;
  final int capturasRealizadas;
  final int totalCapturas;

  const StopButton({
    super.key,
    required this.onPressed,
    required this.capturasRealizadas,
    required this.totalCapturas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.shade200,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Text(
            'Capturando... $capturasRealizadas/$totalCapturas',
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.stop_circle, color: Colors.red, size: 28),
            label: Text(
              'DETENER',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.red.shade200),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
