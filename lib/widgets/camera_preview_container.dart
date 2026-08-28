import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'camera_overlay.dart';

class CameraPreviewContainer extends StatelessWidget {
  final CameraController cameraController;
  final Map<String, dynamic> posicion;
  final bool isCapturing;
  final bool isComplete;

  const CameraPreviewContainer({
    super.key,
    required this.cameraController,
    required this.posicion,
    required this.isCapturing,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    final previewSize = cameraController.value.previewSize!;
    final aspectRatio = previewSize.width / previewSize.height;
    final isFrontCamera =
        cameraController.description.lensDirection == CameraLensDirection.front;

    // Colores de la posición actual
    final posicionColor =
        posicion['color'] as Color? ?? const Color(0xFF5B67CA);

    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final maxHeight = constraints.maxHeight;

              // Calcular dimensiones manteniendo relación 3:4
              double cameraWidth = maxWidth;
              double cameraHeight = cameraWidth * (5 / 3);

              if (cameraHeight > maxHeight) {
                cameraHeight = maxHeight;
                cameraWidth = cameraHeight * (3 / 5);
              }

              return Container(
                width: cameraWidth,
                height: cameraHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: posicionColor.withOpacity(0.3),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: posicionColor.withOpacity(0.15),
                      blurRadius: 30,
                      spreadRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      posicionColor.withOpacity(0.05),
                      Colors.transparent,
                      posicionColor.withOpacity(0.05),
                    ],
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Vista de la cámara
                      AspectRatio(
                        aspectRatio: aspectRatio,
                        child: CameraPreview(cameraController),
                      ),

                      // Overlay de guía
                      if (isFrontCamera)
                        Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                          child: CameraOverlay(
                            width: cameraWidth,
                            height: cameraHeight,
                            icono: posicion['icono'] as IconData,
                            isCapturing: isCapturing,
                            isComplete: isComplete,
                            isFrontCamera: true,
                            posicionColor: posicionColor,
                          ),
                        )
                      else
                        CameraOverlay(
                          width: cameraWidth,
                          height: cameraHeight,
                          icono: posicion['icono'] as IconData,
                          isCapturing: isCapturing,
                          isComplete: isComplete,
                          isFrontCamera: false,
                          posicionColor: posicionColor,
                        ),

                      // Indicador de completado
                      if (isComplete)
                        Positioned.fill(
                          child: Container(
                            color: Colors.green.withOpacity(0.1),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
