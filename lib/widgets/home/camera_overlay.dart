import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraOverlay extends StatelessWidget {
  final CameraController cameraController;
  final String? etapaFoto;
  final String? gestoSolicitado;
  final String Function(String) instruccionGesto;
  final VoidCallback onCapture;
  final VoidCallback onCancel;

  const CameraOverlay({
    super.key,
    required this.cameraController,
    required this.etapaFoto,
    required this.gestoSolicitado,
    required this.instruccionGesto,
    required this.onCapture,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(cameraController),
            if (etapaFoto == 'frontal' || etapaFoto == 'gesto')
              Center(
                child: Container(
                  width: 280,
                  height: 350,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(140),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: _buildInfoContainer(),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildButton(
                    heroTag: 'cancel',
                    backgroundColor: const Color(0xFFE17055),
                    icon: Icons.close_rounded,
                    onPressed: onCancel,
                  ),
                  _buildButton(
                    heroTag: 'capture',
                    backgroundColor: Colors.white,
                    icon: Icons.camera_alt_rounded,
                    iconColor: Colors.black,
                    size: 32,
                    onPressed: onCapture,
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoContainer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getEtapaColor().withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getEtapaIcon(),
              color: _getEtapaColor(),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getEtapaText(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String heroTag,
    required Color backgroundColor,
    required IconData icon,
    Color? iconColor,
    double size = 24,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton(
      heroTag: heroTag,
      backgroundColor: backgroundColor,
      onPressed: onPressed,
      elevation: 4,
      child: Icon(
        icon,
        color: iconColor ?? Colors.white,
        size: size,
      ),
    );
  }

  String _getEtapaText() {
    switch (etapaFoto) {
      case 'frontal':
        return 'Foto FRONTAL - Mire al frente';
      case 'gesto':
        return 'Foto del GESTO - ${instruccionGesto(gestoSolicitado!)}';
      case 'constancia':
        return 'Foto de CONSTANCIA - Entorno';
      default:
        return 'Preparando cámara...';
    }
  }

  Color _getEtapaColor() {
    switch (etapaFoto) {
      case 'frontal':
        return const Color(0xFF5B67CA);
      case 'gesto':
        return const Color(0xFFFDCB6E);
      case 'constancia':
        return const Color(0xFF74B9FF);
      default:
        return const Color(0xFF5B67CA);
    }
  }

  IconData _getEtapaIcon() {
    switch (etapaFoto) {
      case 'frontal':
        return Icons.face_rounded;
      case 'gesto':
        return Icons.accessibility_new_rounded;
      case 'constancia':
        return Icons.photo_camera_rounded;
      default:
        return Icons.camera_alt_rounded;
    }
  }
}
