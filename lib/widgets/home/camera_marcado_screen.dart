import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

class CameraMarcadoScreen extends StatefulWidget {
  final CameraController cameraController;
  final String etapaFoto;
  final String? gestoSolicitado;
  final String Function(String) instruccionGesto;
  final VoidCallback onCapture;
  final VoidCallback onCancel;
  final List<CameraDescription> cameras;

  const CameraMarcadoScreen({
    super.key,
    required this.cameraController,
    required this.etapaFoto,
    required this.gestoSolicitado,
    required this.instruccionGesto,
    required this.onCapture,
    required this.onCancel,
    required this.cameras,
  });

  @override
  State<CameraMarcadoScreen> createState() => _CameraMarcadoScreenState();
}

class _CameraMarcadoScreenState extends State<CameraMarcadoScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late CameraController _cameraController;

  bool _isCapturing = false;
  bool _isFrontCamera = true;
  double _zoomLevel = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 3.0;
  bool _isFlashOn = false;
  bool _isInitializing = true;

  // Colores iOS
  static const Color _primary = Color(0xFF007AFF);
  static const Color _warning = Color(0xFFFF9500);
  static const Color _success = Color(0xFF34C759);
  static const Color _info = Color(0xFF5AC8FA);

  @override
  void initState() {
    super.initState();
    _cameraController = widget.cameraController;
    _isFrontCamera = _cameraController.description.lensDirection ==
        CameraLensDirection.front; // ARREGLO 1
    _initCamera();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initCamera() async {
    try {
      _minZoom = await _cameraController.getMinZoomLevel();
      _maxZoom = await _cameraController.getMaxZoomLevel();
      _zoomLevel = _minZoom;
      await _cameraController
          .setFocusMode(FocusMode.auto); // ARREGLO 2: Auto focus
      setState(() => _isInitializing = false);
    } catch (e) {
      setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || !_cameraController.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black, // ARREGLO 3: Fondo negro
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black, // ARREGLO 4: Fondo negro
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCameraWithOverlay(), // ARREGLO 5: Overlay con hueco
            _buildTopBar(),
            _buildInstructions(),
            _buildBottomControls(),
            if (_isCapturing) _buildCaptureAnimation(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraWithOverlay() {
    final screenSize = MediaQuery.of(context).size;
    final frameWidth = (screenSize.width * 0.75).clamp(280.0, 380.0);
    final frameHeight = frameWidth * 1.333; // 3:4

    return Stack(
      children: [
        CameraPreview(_cameraController),
        // Overlay oscuro con hueco transparente
        CustomPaint(
          painter:
              _HolePainter(frameWidth: frameWidth, frameHeight: frameHeight),
          child: Container(),
        ),
        // Marco solo para frontal y gesto
        if (widget.etapaFoto == 'frontal' || widget.etapaFoto == 'gesto')
          Center(child: _buildAnimatedFrame(frameWidth, frameHeight)),
      ],
    );
  }

  Widget _buildAnimatedFrame(double w, double h) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _getEtapaColor(), width: 2.5),
            ),
            child: Stack(
              children: [
                _buildGuideLines(),
                _buildCornerBorder(Alignment.topLeft),
                _buildCornerBorder(Alignment.topRight),
                _buildCornerBorder(Alignment.bottomLeft),
                _buildCornerBorder(Alignment.bottomRight),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuideLines() {
    return Stack(
      children: [
        Positioned(
            top: 28,
            left: 16,
            right: 16,
            child: Container(height: 1, color: Colors.white.withOpacity(0.15))),
        Positioned(
            top: 55,
            left: 16,
            right: 16,
            child: Container(height: 1, color: Colors.white.withOpacity(0.15))),
        Positioned(
            top: 82,
            left: 16,
            right: 16,
            child: Container(height: 1, color: Colors.white.withOpacity(0.15))),
        Center(
            child: Container(
                width: 1,
                height: double.infinity,
                color: Colors.white.withOpacity(0.1))),
      ],
    );
  }

  Widget _buildCornerBorder(Alignment alignment) {
    final color = _getEtapaColor();
    return Align(
      alignment: alignment,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            left: alignment == Alignment.topLeft ||
                    alignment == Alignment.bottomLeft
                ? BorderSide(color: color, width: 3.5)
                : BorderSide.none,
            right: alignment == Alignment.topRight ||
                    alignment == Alignment.bottomRight
                ? BorderSide(color: color, width: 3.5)
                : BorderSide.none,
            top: alignment == Alignment.topLeft ||
                    alignment == Alignment.topRight
                ? BorderSide(color: color, width: 3.5)
                : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft ||
                    alignment == Alignment.bottomRight
                ? BorderSide(color: color, width: 3.5)
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
              icon: Icons.close_rounded, onPressed: widget.onCancel),
          _buildStepIndicator(),
          _buildCircleButton(
              icon: Icons.help_outline_rounded, onPressed: _showHelpDialog),
        ],
      ),
    );
  }

  Widget _buildCircleButton(
      {required IconData icon, required VoidCallback onPressed}) {
    return Material(
      color: Colors.black.withOpacity(0.5), // Botones oscuros iOS
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 22)),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final currentStep = _getCurrentStep();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _buildStepDot(currentStep >= 1),
        _buildStepLine(currentStep >= 2),
        _buildStepDot(currentStep >= 2),
        _buildStepLine(currentStep >= 3),
        _buildStepDot(currentStep >= 3),
      ]),
    );
  }

  Widget _buildStepDot(bool isActive) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
          color: isActive ? _getEtapaColor() : Colors.white24,
          shape: BoxShape.circle));
  Widget _buildStepLine(bool isActive) => Container(
      width: 18,
      height: 1.5,
      color: isActive ? _getEtapaColor() : Colors.white24);

  Widget _buildInstructions() {
    return Positioned(
      top: 80,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_getEtapaIcon(), color: _getEtapaColor(), size: 18),
            const SizedBox(width: 8),
            Text(_getEtapaTitle(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Text(_getEtapaInstructions(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _buildBottomControls() {
    final hasMultipleCameras = widget.cameras.length > 1;
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Column(children: [
        _buildZoomControls(),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _buildActionButton(
              icon: Icons.flash_on_rounded,
              onPressed: _toggleFlash,
              isActive: _isFlashOn),
          const SizedBox(width: 20),
          _buildCaptureButton(),
          const SizedBox(width: 20),
          if (hasMultipleCameras)
            _buildActionButton(
                icon: Icons.cameraswitch_rounded,
                onPressed: _flipCamera,
                isActive: false)
          else
            const SizedBox(width: 46),
        ]),
      ]),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.zoom_out_rounded, color: Colors.white70, size: 18),
        const SizedBox(width: 4),
        SizedBox(
          width: 100,
          child: Slider(
            value: _zoomLevel,
            min: _minZoom,
            max: _maxZoom,
            activeColor: _getEtapaColor(),
            inactiveColor: Colors.white24,
            onChanged: (value) async {
              setState(() => _zoomLevel = value);
              await _cameraController.setZoomLevel(value);
            },
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 18),
      ]),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required VoidCallback onPressed,
      required bool isActive}) {
    return Material(
      color: isActive ? _getEtapaColor() : Colors.black.withOpacity(0.5),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(icon,
                color: isActive ? Colors.white : Colors.white70, size: 22)),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isCapturing ? 0.85 : 1.0,
          child: GestureDetector(
            onTap: _handleCapture,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: _getEtapaColor(), width: 4),
                boxShadow: [
                  BoxShadow(
                      color: _getEtapaColor().withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 4)
                ],
              ),
              child: Icon(Icons.camera_alt_rounded,
                  color: _getEtapaColor(), size: 28),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCaptureAnimation() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration:
                      BoxDecoration(color: _success, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 56),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleCapture() async {
    if (_isCapturing) return;
    HapticFeedback.mediumImpact(); // Vibración iOS
    setState(() => _isCapturing = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() => _isCapturing = false);
      widget.onCapture();
    }
  }

  Future<void> _flipCamera() async {
    if (widget.cameras.length < 2) return;
    HapticFeedback.lightImpact();
    setState(() => _isInitializing = true);
    await _cameraController.dispose();

    final newCamera = widget.cameras.firstWhere(
      (c) =>
          c.lensDirection ==
          (_isFrontCamera
              ? CameraLensDirection.back
              : CameraLensDirection.front),
      orElse: () => widget.cameras.first,
    );

    _cameraController =
        CameraController(newCamera, ResolutionPreset.high, enableAudio: false);
    await _cameraController.initialize();
    _isFrontCamera = !_isFrontCamera;
    await _initCamera();
  }

  Future<void> _toggleFlash() async {
    setState(() => _isFlashOn = !_isFlashOn);
    await _cameraController
        .setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
  }

  void _showHelpDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                Icon(Icons.help_rounded, color: _getEtapaColor()),
                const SizedBox(width: 12),
                const Text('Consejos', style: TextStyle(color: Colors.white))
              ]),
              content: Text(_getEtapaInstructions(),
                  style: const TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Entendido',
                        style: TextStyle(color: _getEtapaColor())))
              ],
            ));
  }

  int _getCurrentStep() => widget.etapaFoto == 'frontal'
      ? 1
      : widget.etapaFoto == 'gesto'
          ? 2
          : 3;
  String _getEtapaTitle() => widget.etapaFoto == 'frontal'
      ? 'Foto Frontal'
      : widget.etapaFoto == 'gesto'
          ? 'Foto con Gesto'
          : 'Foto de Constancia';
  String _getEtapaInstructions() => widget.etapaFoto == 'gesto'
      ? widget.instruccionGesto(widget.gestoSolicitado!)
      : widget.etapaFoto == 'frontal'
          ? 'Mira directamente a la cámara\nMantén tu rostro dentro del marco'
          : 'Toma una foto del entorno para constancia';
  Color _getEtapaColor() => widget.etapaFoto == 'frontal'
      ? _primary
      : widget.etapaFoto == 'gesto'
          ? _warning
          : _info;
  IconData _getEtapaIcon() => widget.etapaFoto == 'frontal'
      ? Icons.face_rounded
      : widget.etapaFoto == 'gesto'
          ? Icons.accessibility_new_rounded
          : Icons.photo_camera_rounded;
}

// PINTOR PARA OVERLAY CON HUECO
class _HolePainter extends CustomPainter {
  final double frameWidth;
  final double frameHeight;
  _HolePainter({required this.frameWidth, required this.frameHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..style = PaintingStyle.fill;
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final center = Offset(size.width / 2, size.height / 2);
    final rect =
        Rect.fromCenter(center: center, width: frameWidth, height: frameHeight);
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
    final finalPath = Path.combine(PathOperation.difference, path, holePath);
    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
