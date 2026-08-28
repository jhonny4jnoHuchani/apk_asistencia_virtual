import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:ui' as ui;

class CameraMarcadoScreen extends StatefulWidget {
  final CameraController cameraController;
  final String etapaFoto;
  final String? gestoSolicitado;
  final String Function(String) instruccionGesto;
  final VoidCallback onCapture;
  final VoidCallback onCancel;

  const CameraMarcadoScreen({
    super.key,
    required this.cameraController,
    required this.etapaFoto,
    required this.gestoSolicitado,
    required this.instruccionGesto,
    required this.onCapture,
    required this.onCancel,
  });

  @override
  State<CameraMarcadoScreen> createState() => _CameraMarcadoScreenState();
}

class _CameraMarcadoScreenState extends State<CameraMarcadoScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isCapturing = false;
  bool _isFrontCamera = true;
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildWhiteBackground(),
            _buildCameraPreview(),
            _buildPhotoFrame(),
            _buildTopBar(),
            _buildInstructions(),
            _buildBottomControls(),
            if (_isCapturing) _buildCaptureAnimation(),
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteBackground() {
    return Container(
      color: Colors.white,
    );
  }

  Widget _buildCameraPreview() {
    // Mostrar la cámara solo dentro del área del marco 3x4
    final screenSize = MediaQuery.of(context).size;
    // final frameWidth = screenSize.width * 0.75;
    final frameWidth = screenSize.width * 0.70;
    // final frameHeight = frameWidth * 1.333; // Relación 3:4
    final frameHeight = frameWidth * 1.555; // Relación 3:4

    return Center(
      child: Container(
        width: frameWidth,
        height: frameHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CameraPreview(widget.cameraController),
        ),
      ),
    );
  }

  Widget _buildPhotoFrame() {
    final screenSize = MediaQuery.of(context).size;
    final frameWidth = screenSize.width * 0.70;
    final frameHeight = frameWidth * 1.555; // Relación 3:4

    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: frameWidth,
          height: frameHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getEtapaColor(),
              width: 3,
            ),
          ),
          child: Stack(
            children: [
              // Guías internas
              _buildGuideLines(),

              // Esquinas decorativas
              _buildCornerBorder(Alignment.topLeft),
              _buildCornerBorder(Alignment.topRight),
              _buildCornerBorder(Alignment.bottomLeft),
              _buildCornerBorder(Alignment.bottomRight),

              // Indicador central cuando no hay rostro
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getEtapaIcon(),
                      color: Colors.grey.withOpacity(0.3),
                      size: 40,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '3x4',
                      style: TextStyle(
                        color: Colors.grey.withOpacity(0.3),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideLines() {
    return Stack(
      children: [
        // Línea superior (ojos)
        Positioned(
          top: 30,
          left: 15,
          right: 15,
          child: Container(
            height: 1,
            color: _getEtapaColor().withOpacity(0.3),
          ),
        ),
        // Línea media (nariz)
        Positioned(
          top: 60,
          left: 15,
          right: 15,
          child: Container(
            height: 1,
            color: _getEtapaColor().withOpacity(0.3),
          ),
        ),
        // Línea inferior (boca)
        Positioned(
          top: 90,
          left: 15,
          right: 15,
          child: Container(
            height: 1,
            color: _getEtapaColor().withOpacity(0.3),
          ),
        ),
        // Línea vertical central
        Center(
          child: Container(
            width: 1,
            height: double.infinity,
            color: _getEtapaColor().withOpacity(0.2),
          ),
        ),
      ],
    );
  }

  Widget _buildCornerBorder(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 25,
        height: 25,
        decoration: BoxDecoration(
          border: Border(
            left: alignment == Alignment.topLeft ||
                    alignment == Alignment.bottomLeft
                ? BorderSide(color: _getEtapaColor(), width: 4)
                : BorderSide.none,
            right: alignment == Alignment.topRight ||
                    alignment == Alignment.bottomRight
                ? BorderSide(color: _getEtapaColor(), width: 4)
                : BorderSide.none,
            top: alignment == Alignment.topLeft ||
                    alignment == Alignment.topRight
                ? BorderSide(color: _getEtapaColor(), width: 4)
                : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft ||
                    alignment == Alignment.bottomRight
                ? BorderSide(color: _getEtapaColor(), width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleButton(
            icon: Icons.close_rounded,
            onPressed: widget.onCancel,
            backgroundColor: Colors.white,
            iconColor: Colors.black87,
          ),
          _buildStepIndicator(),
          _buildCircleButton(
            icon: Icons.help_outline_rounded,
            onPressed: _showHelpDialog,
            backgroundColor: Colors.white,
            iconColor: Colors.black87,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    Color? iconColor,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: iconColor ?? Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final currentStep = _getCurrentStep();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStepDot(1, currentStep >= 1),
          _buildStepLine(currentStep >= 2),
          _buildStepDot(2, currentStep >= 2),
          _buildStepLine(currentStep >= 3),
          _buildStepDot(3, currentStep >= 3),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, bool isActive) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: isActive ? _getEtapaColor() : Colors.grey.shade300,
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: _getEtapaColor().withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Container(
      width: 20,
      height: 2,
      color: isActive ? _getEtapaColor() : Colors.grey.shade300,
    );
  }

  Widget _buildInstructions() {
    return Positioned(
      top: 80,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getEtapaColor().withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _getEtapaColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getEtapaIcon(),
                    color: _getEtapaColor(),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getEtapaTitle(),
                  style: const TextStyle(
                    color: Color(0xFF2D3436),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _getEtapaInstructions(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF636E72),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Column(
        children: [
          _buildZoomControls(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCancelButton(),
              const SizedBox(width: 40),
              _buildCaptureButton(),
              const SizedBox(width: 40),
              _buildFlipCameraButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.zoom_out_rounded, color: Colors.grey.shade600, size: 18),
          const SizedBox(width: 4),
          Container(
            width: 80,
            child: Slider(
              value: _zoomLevel,
              min: 1.0,
              max: 3.0,
              activeColor: _getEtapaColor(),
              inactiveColor: Colors.grey.shade300,
              onChanged: (value) {
                setState(() => _zoomLevel = value);
              },
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.zoom_in_rounded, color: Colors.grey.shade600, size: 18),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade400,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade400.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onCancel,
          customBorder: const CircleBorder(),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isCapturing ? 0.9 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getEtapaColor().withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _handleCapture,
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _getEtapaColor(),
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: _getEtapaColor(),
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFlipCameraButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: _flipCamera,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(
            Icons.flip_camera_ios_rounded,
            color: Colors.grey.shade700,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureAnimation() {
    return Positioned.fill(
      child: Container(
        color: Colors.white.withOpacity(0.8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _getEtapaColor(),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 60,
            ),
          ),
        ),
      ),
    );
  }

  void _handleCapture() {
    setState(() => _isCapturing = true);

    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() => _isCapturing = false);
      widget.onCapture();
    });
  }

  void _flipCamera() {
    setState(() => _isFrontCamera = !_isFrontCamera);
    // Aquí deberías implementar el cambio real de cámara
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.help_rounded, color: _getEtapaColor()),
            const SizedBox(width: 12),
            const Text('Ayuda para la foto'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHelpItem(
              icon: Icons.person_rounded,
              text: 'Coloca tu rostro dentro del marco 3x4',
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              icon: Icons.lightbulb_rounded,
              text: 'Asegúrate de tener buena iluminación',
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              icon: Icons.center_focus_strong_rounded,
              text: 'Centra tu rostro en el área visible',
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              icon: Icons.zoom_in_rounded,
              text: 'Usa el zoom para ajustar el encuadre',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getEtapaColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _getEtapaColor(), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  int _getCurrentStep() {
    switch (widget.etapaFoto) {
      case 'frontal':
        return 1;
      case 'gesto':
        return 2;
      case 'constancia':
        return 3;
      default:
        return 1;
    }
  }

  String _getEtapaTitle() {
    switch (widget.etapaFoto) {
      case 'frontal':
        return 'Foto Frontal 3x4';
      case 'gesto':
        return 'Foto con Gesto 3x4';
      case 'constancia':
        return 'Foto de Constancia';
      default:
        return '';
    }
  }

  String _getEtapaInstructions() {
    switch (widget.etapaFoto) {
      case 'frontal':
        return 'Mira directamente a la cámara\nMantén tu rostro dentro del marco';
      case 'gesto':
        return widget.instruccionGesto(widget.gestoSolicitado!);
      case 'constancia':
        return 'Toma una foto del entorno para constancia';
      default:
        return '';
    }
  }

  Color _getEtapaColor() {
    switch (widget.etapaFoto) {
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
    switch (widget.etapaFoto) {
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
