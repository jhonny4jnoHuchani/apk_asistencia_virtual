import 'package:flutter/material.dart';

class MarcadoDialog extends StatelessWidget {
  const MarcadoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF5B67CA),
            ),
            const SizedBox(height: 16),
            const Text(
              'Procesando marcado...',
              style: TextStyle(
                color: Color(0xFF2D3436),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Por favor espere',
              style: TextStyle(
                color: Color(0xFF636E72),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
