import 'package:flutter/material.dart';

class CameraControls extends StatelessWidget {
  final VoidCallback onCapture;
  final VoidCallback onCancel;
  final VoidCallback onFlipCamera;
  final Color accentColor;

  const CameraControls({
    super.key,
    required this.onCapture,
    required this.onCancel,
    required this.onFlipCamera,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          icon: Icons.close_rounded,
          color: Colors.red.shade400,
          onPressed: onCancel,
        ),
        const SizedBox(width: 40),
        _buildCaptureButton(),
        const SizedBox(width: 40),
        _buildControlButton(
          icon: Icons.flip_camera_ios_rounded,
          color: Colors.black.withOpacity(0.5),
          onPressed: onFlipCamera,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onCapture,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor,
                width: 3,
              ),
            ),
            child: Icon(
              Icons.camera_alt_rounded,
              color: accentColor,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}
