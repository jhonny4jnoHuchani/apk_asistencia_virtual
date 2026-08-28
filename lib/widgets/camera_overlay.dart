import 'package:flutter/material.dart';
import 'dart:math' as math;

class CameraOverlay extends StatelessWidget {
  final double width;
  final double height;
  final IconData icono;
  final bool isCapturing;
  final bool isComplete;
  final bool isFrontCamera;
  final Color posicionColor;

  const CameraOverlay({
    super.key,
    required this.width,
    required this.height,
    required this.icono,
    required this.isCapturing,
    required this.isComplete,
    this.isFrontCamera = false,
    this.posicionColor = const Color(0xFF5B67CA),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Líneas de guía
        ..._buildVerticalLines(),
        ..._buildHorizontalLines(),

        // Puntos de intersección
        ..._buildIntersectionPoints(),

        // Esquinas decorativas
        ..._buildCornerIndicators(),

        // Marco ovalado para el rostro
        _buildFaceGuide(),

        // Icono central
        _buildCenterIcon(),

        // Indicador de captura
        if (isCapturing) _buildCaptureIndicator(),

        // Texto de estado
        if (isComplete) _buildCompleteText(),
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
          color: Colors.white.withOpacity(0.2),
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
          color: Colors.white.withOpacity(0.2),
        ),
      );
    });
  }

  List<Widget> _buildIntersectionPoints() {
    final points = <Widget>[];

    for (int row = 1; row <= 2; row++) {
      for (int col = 1; col <= 2; col++) {
        points.add(
          Positioned(
            left: col * (width / 3) - 6,
            top: row * (height / 3) - 6,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isCapturing
                    ? posicionColor.withOpacity(0.6)
                    : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: isCapturing
                      ? posicionColor.withOpacity(0.8)
                      : Colors.white.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: isCapturing
                    ? [
                        BoxShadow(
                          color: posicionColor.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );
      }
    }

    return points;
  }

  List<Widget> _buildCornerIndicators() {
    final positions = [
      {'top': true, 'left': true},
      {'top': true, 'left': false},
      {'top': false, 'left': true},
      {'top': false, 'left': false},
    ];

    return positions.map((pos) {
      final isTop = pos['top'] as bool;
      final isLeft = pos['left'] as bool;

      return Positioned(
        top: isTop ? 12 : null,
        bottom: !isTop ? 12 : null,
        left: isLeft ? 12 : null,
        right: !isLeft ? 12 : null,
        child: Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            border: Border(
              top: isTop
                  ? BorderSide(
                      color: isCapturing
                          ? posicionColor.withOpacity(0.8)
                          : Colors.white.withOpacity(0.5),
                      width: 3,
                    )
                  : BorderSide.none,
              bottom: !isTop
                  ? BorderSide(
                      color: isCapturing
                          ? posicionColor.withOpacity(0.8)
                          : Colors.white.withOpacity(0.5),
                      width: 3,
                    )
                  : BorderSide.none,
              left: isLeft
                  ? BorderSide(
                      color: isCapturing
                          ? posicionColor.withOpacity(0.8)
                          : Colors.white.withOpacity(0.5),
                      width: 3,
                    )
                  : BorderSide.none,
              right: !isLeft
                  ? BorderSide(
                      color: isCapturing
                          ? posicionColor.withOpacity(0.8)
                          : Colors.white.withOpacity(0.5),
                      width: 3,
                    )
                  : BorderSide.none,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildFaceGuide() {
    // Guía ovalada para el rostro
    final ovalWidth = width * 0.45;
    final ovalHeight = height * 0.45;

    return Center(
      child: Container(
        width: ovalWidth,
        height: ovalHeight,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isCapturing
                ? posicionColor.withOpacity(0.6)
                : Colors.white.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: isCapturing
              ? [
                  BoxShadow(
                    color: posicionColor.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Widget _buildCenterIcon() {
    return Center(
      child: AnimatedOpacity(
        opacity: isComplete ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 500),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(60),
            border: Border.all(
              color: isCapturing
                  ? posicionColor.withOpacity(0.5)
                  : Colors.white.withOpacity(0.15),
              width: 2,
            ),
            boxShadow: isCapturing
                ? [
                    BoxShadow(
                      color: posicionColor.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Transform(
            alignment: Alignment.center,
            transform: _getTransformMatrix(),
            child: Icon(
              icono,
              color: isCapturing
                  ? posicionColor.withOpacity(0.8)
                  : Colors.white.withOpacity(0.5),
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

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
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
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

  Widget _buildCompleteText() {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Transform(
          alignment: Alignment.center,
          // Aplicar transformación inversa si es cámara frontal
          transform: isFrontCamera
              ? (Matrix4.identity()..scale(-1.0, 1.0, 1.0))
              : Matrix4.identity(),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Registro Completo',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
