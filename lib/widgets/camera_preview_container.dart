// widgets/camera_preview_container.dart
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

    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final maxHeight = constraints.maxHeight;
              double cameraWidth = maxWidth;
              double cameraHeight = cameraWidth * (4 / 3);

              if (cameraHeight > maxHeight) {
                cameraHeight = maxHeight;
                cameraWidth = cameraHeight * (3 / 4);
              }

              return Container(
                width: cameraWidth,
                height: cameraHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.deepPurple.withOpacity(0.15),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.08),
                      blurRadius: 30,
                      spreadRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AspectRatio(
                        aspectRatio: aspectRatio,
                        child: CameraPreview(cameraController),
                      ),
                      if (isFrontCamera)
                        Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                          child: Container(
                            color: Colors.transparent,
                            child: CameraOverlay(
                              width: cameraWidth,
                              height: cameraHeight,
                              icono: posicion['icono'] as IconData,
                              isCapturing: isCapturing,
                              isComplete: isComplete,
                              isFrontCamera: true, // <- Pasamos el parámetro
                            ),
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
