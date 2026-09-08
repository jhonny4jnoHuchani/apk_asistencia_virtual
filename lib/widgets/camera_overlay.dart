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
        ..._buildVerticalLines(),
        ..._buildHorizontalLines(),
        ..._buildIntersectionPoints(),
        ..._buildCornerIndicators(),
        _buildFaceGuide(),
        _buildCenterIcon(),
        if (isCapturing) _buildCaptureIndicator(),
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
    final isSmall = width < 360;
    final iconSize = isSmall ? 28.0 : 32.0;
    final padding = isSmall ? 10.0 : 12.0;
    final borderRadius = isSmall ? 40.0 : 50.0;

    return Center(
      child: AnimatedOpacity(
        opacity: isComplete ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 400),
        child: AnimatedScale(
          scale: isCapturing ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isCapturing
                    ? posicionColor.withOpacity(0.6)
                    : Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: isCapturing
                  ? [
                      BoxShadow(
                        color: posicionColor.withOpacity(0.25),
                        blurRadius: 12,
                        spreadRadius: 2,
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
                    ? posicionColor.withOpacity(0.9)
                    : Colors.white.withOpacity(0.6),
                size: iconSize,
              ),
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
    final isSmall = width < 360;
    final size = isSmall ? 12.0 : 14.0;
    final padding = isSmall ? 6.0 : 7.0;
    return Positioned(
      bottom: isSmall ? 12 : 14,
      right: isSmall ? 12 : 14,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.25),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }

  // ─── REGISTRO COMPLETADO CON BOTÓN MÁS PEQUEÑO ───
  Widget _buildCompleteText() {
    final isSmall = width < 360;
    final fontSize = isSmall ? 11.0 : 12.0;
    final iconSize = isSmall ? 16.0 : 18.0;
    final paddingH = isSmall ? 12.0 : 14.0;
    final paddingV = isSmall ? 5.0 : 6.0;
    final borderRadius = isSmall ? 14.0 : 16.0;

    return Positioned(
      top: isSmall ? 12 : 16,
      left: 0,
      right: 0,
      child: Center(
        child: Transform(
          alignment: Alignment.center,
          transform: isFrontCamera
              ? (Matrix4.identity()..scale(-1.0, 1.0, 1.0))
              : Matrix4.identity(),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: paddingH,
              vertical: paddingV,
            ),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.9),
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: iconSize,
                ),
                SizedBox(width: isSmall ? 4 : 6),
                Text(
                  'Registro Completado',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSize,
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
