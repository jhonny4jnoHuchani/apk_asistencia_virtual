// widgets/camera_overlay.dart
import 'package:flutter/material.dart';

class CameraOverlay extends StatelessWidget {
  final double width;
  final double height;
  final IconData icono;
  final bool isCapturing;
  final bool isComplete;
  final bool isFrontCamera;

  const CameraOverlay({
    super.key,
    required this.width,
    required this.height,
    required this.icono,
    required this.isCapturing,
    required this.isComplete,
    this.isFrontCamera = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ..._buildVerticalLines(),
        ..._buildHorizontalLines(),
        ..._buildIntersectionPoints(),
        ..._buildCornerIndicators(),
        _buildCenterIcon(),
        if (isCapturing) _buildCaptureIndicator(),
      ],
    );
  }

  List<Widget> _buildVerticalLines() {
    return List.generate(2, (index) {
      return Positioned(
        left: (index + 1) * (width / 3),
        top: 0,
        bottom: 0,
        child: Container(
          width: 1.5,
          color: Colors.white.withOpacity(0.25),
        ),
      );
    });
  }

  List<Widget> _buildHorizontalLines() {
    return List.generate(2, (index) {
      return Positioned(
        top: (index + 1) * (height / 3),
        left: 0,
        right: 0,
        child: Container(
          height: 1.5,
          color: Colors.white.withOpacity(0.25),
        ),
      );
    });
  }

  List<Widget> _buildIntersectionPoints() {
    return List.generate(2, (row) {
      return List.generate(2, (col) {
        return Positioned(
          left: (col + 1) * (width / 3) - 6,
          top: (row + 1) * (height / 3) - 6,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 2,
              ),
            ),
          ),
        );
      });
    }).expand((element) => element).toList();
  }

  List<Widget> _buildCornerIndicators() {
    const positions = [
      [12, 12],
      [12, null],
      [null, 12],
      [null, null],
    ];

    return positions.map((pos) {
      final isLeft = pos[0] != null;
      final isTop = pos[1] != null;

      return Positioned(
        top: isTop ? 12 : null,
        bottom: !isTop ? 12 : null,
        left: isLeft ? 12 : null,
        right: !isLeft ? 12 : null,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              top: isTop
                  ? BorderSide(
                      color: Colors.white.withOpacity(0.5),
                      width: 3,
                    )
                  : BorderSide.none,
              bottom: !isTop
                  ? BorderSide(
                      color: Colors.white.withOpacity(0.5),
                      width: 3,
                    )
                  : BorderSide.none,
              left: isLeft
                  ? BorderSide(
                      color: Colors.white.withOpacity(0.5),
                      width: 3,
                    )
                  : BorderSide.none,
              right: !isLeft
                  ? BorderSide(
                      color: Colors.white.withOpacity(0.5),
                      width: 3,
                    )
                  : BorderSide.none,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildCenterIcon() {
    return Center(
      child: AnimatedOpacity(
        opacity: isComplete ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 500),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Transform(
            alignment: Alignment.center,
            // CORREGIDO: Usar un getter o método para el transform
            transform: _getTransformMatrix(),
            child: Icon(
              icono,
              color: Colors.white.withOpacity(0.5),
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  // Método auxiliar para obtener la matriz de transformación
  Matrix4 _getTransformMatrix() {
    if (isFrontCamera) {
      return Matrix4.identity()..scale(-1.0, 1.0, 1.0);
    } else {
      return Matrix4.identity();
    }
  }

  Widget _buildCaptureIndicator() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }
}
