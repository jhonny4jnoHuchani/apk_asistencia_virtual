import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late CameraController _controller;

  bool _isCapturing = false;
  double _zoomLevel = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  bool _isFlashOn = false;
  bool _isInitializing = true;
  bool _cameraError = false;
  bool _isDisposed = false;
  bool _isFrontCamera = false;
  bool _hasFlash = false;

  static const Color _primary = Color(0xFF007AFF);
  static const Color _warning = Color(0xFFFF9500);
  static const Color _success = Color(0xFF34C759);
  static const Color _info = Color(0xFF5AC8FA);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = widget.cameraController;
    _isFrontCamera =
        _controller.description.lensDirection == CameraLensDirection.front;

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_isDisposed || !_controller.value.isInitialized) return;
    try {
      if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.hidden) {
        await _controller.pausePreview();
      } else if (state == AppLifecycleState.resumed) {
        await _controller.resumePreview();
        await _controller
            .setFocusMode(FocusMode.auto); // iOS pierde focus al volver
      }
    } catch (e) {
      debugPrint('Lifecycle error: $e');
    }
  }

  Future<void> _initCamera() async {
    if (_isDisposed || !mounted) return;
    setState(() => _isInitializing = true);

    try {
      if (!_controller.value.isInitialized) {
        await _controller.initialize();
      }

      // iOS 17: obtener rangos de zoom de forma segura
      try {
        _minZoom = await _controller.getMinZoomLevel();
        _maxZoom = await _controller.getMaxZoomLevel();
        _zoomLevel = _minZoom;
      } catch (_) {
        _minZoom = 1.0;
        _maxZoom = 1.0;
        _zoomLevel = 1.0;
      }

      // Detectar flash
      try {
        _hasFlash = _controller.value.flashMode != FlashMode.off; // proxy
      } catch (_) {
        _hasFlash = !_isFrontCamera;
      }

      await _controller.setFocusMode(FocusMode.auto);
      await _controller.setExposureMode(ExposureMode.auto);

      if (mounted && !_isDisposed) {
        setState(() {
          _isInitializing = false;
          _cameraError = false;
        });
      }
    } catch (e) {
      debugPrint('Error al iniciar cámara: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _isInitializing = false;
          _cameraError = true;
        });
        _mostrarErrorCamara();
      }
    }
  }

  void _mostrarErrorCamara() {
    if (_isDisposed || !mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Error de cámara'),
          ],
        ),
        content: const Text(
          'No se pudo iniciar la cámara.\nVerifica permisos en Ajustes > TuApp > Cámara.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted && !_isDisposed) widget.onCancel();
            },
            child: Text('Salir', style: TextStyle(color: _primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError) return _buildErrorScreen();
    if (_isInitializing || !_controller.value.isInitialized) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        // iOS notch
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCameraWithOverlay(),
            _buildTopBar(),
            _buildInstructions(),
            _buildBottomControls(),
            if (_isCapturing) _buildCaptureAnimation(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                const Text('Error al iniciar cámara',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Verifica los permisos en Ajustes',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => widget.onCancel(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Salir'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
            SizedBox(height: 12),
            Text('Iniciando cámara...',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraWithOverlay() {
    final screenSize = MediaQuery.of(context).size;
    final frameSize = (screenSize.width * 0.8).clamp(220.0, 320.0);
    final frameWidth = frameSize;
    final frameHeight = frameSize * 1.333;

    return GestureDetector(
      onTapDown: _onTapToFocus, // iOS tap to focus
      child: Stack(
        children: [
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: ClipRect(child: CameraPreview(_controller)),
            ),
          ),
          CustomPaint(
            painter:
                _HolePainter(frameWidth: frameWidth, frameHeight: frameHeight),
            child: Container(),
          ),
          if (widget.etapaFoto == 'frontal' || widget.etapaFoto == 'gesto')
            Center(child: _buildAnimatedFrame(frameWidth, frameHeight)),
        ],
      ),
    );
  }

  Future<void> _onTapToFocus(TapDownDetails details) async {
    if (_isDisposed) return;
    final size = MediaQuery.of(context).size;
    final x = details.localPosition.dx / size.width;
    final y = details.localPosition.dy / size.height;
    try {
      await _controller.setFocusPoint(Offset(x, y));
      await _controller.setExposurePoint(Offset(x, y));
    } catch (_) {}
  }

  Widget _buildAnimatedFrame(double w, double h) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) => Transform.scale(
        scale: _pulseAnimation.value,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _getEtapaColor().withOpacity(0.8), width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: _getEtapaColor().withOpacity(0.2),
                  blurRadius: 24,
                  spreadRadius: 1)
            ],
          ),
          child: Stack(
            children: [
              _buildGuideLines(w, h),
              _buildCornerBorder(Alignment.topLeft),
              _buildCornerBorder(Alignment.topRight),
              _buildCornerBorder(Alignment.bottomLeft),
              _buildCornerBorder(Alignment.bottomRight),
              if (widget.etapaFoto == 'gesto' && widget.gestoSolicitado != null)
                Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: _buildGestoIndicator()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGestoIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _warning.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pan_tool_rounded, color: _warning, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              widget.instruccionGesto(widget.gestoSolicitado!),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideLines(double w, double h) {
    final lineColor = Colors.white.withOpacity(0.08);
    return Stack(
      children: [
        Positioned(
            top: h * 0.33,
            left: 16,
            right: 16,
            child: Container(height: 1, color: lineColor)),
        Positioned(
            top: h * 0.66,
            left: 16,
            right: 16,
            child: Container(height: 1, color: lineColor)),
        Positioned(
            left: w * 0.33,
            top: 16,
            bottom: 16,
            child: Container(width: 1, color: lineColor)),
        Positioned(
            left: w * 0.66,
            top: 16,
            bottom: 16,
            child: Container(width: 1, color: lineColor)),
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
            left: alignment.x < 0
                ? BorderSide(color: color, width: 3.5)
                : BorderSide.none,
            right: alignment.x > 0
                ? BorderSide(color: color, width: 3.5)
                : BorderSide.none,
            top: alignment.y < 0
                ? BorderSide(color: color, width: 3.5)
                : BorderSide.none,
            bottom: alignment.y > 0
                ? BorderSide(color: color, width: 3.5)
                : BorderSide.none,
          ),
          borderRadius: _getBorderRadius(alignment),
        ),
      ),
    );
  }

  BorderRadius _getBorderRadius(Alignment a) {
    if (a == Alignment.topLeft)
      return const BorderRadius.only(topLeft: Radius.circular(20));
    if (a == Alignment.topRight)
      return const BorderRadius.only(topRight: Radius.circular(20));
    if (a == Alignment.bottomLeft)
      return const BorderRadius.only(bottomLeft: Radius.circular(20));
    return const BorderRadius.only(bottomRight: Radius.circular(20));
  }

  Widget _glassContainer({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), // más blur para iOS
        child: Container(
          padding: padding ?? const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _glassButton({required IconData icon, required VoidCallback onTap}) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(18),
          child:
              _glassContainer(child: Icon(icon, color: Colors.white, size: 20)),
        ),
      );

  Widget _stepIndicator() => _glassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(_getCurrentStep() >= 1),
            _line(_getCurrentStep() >= 2),
            _dot(_getCurrentStep() >= 2),
            _line(_getCurrentStep() >= 3),
            _dot(_getCurrentStep() >= 3),
          ],
        ),
      );

  Widget _dot(bool active) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
            color: active ? _getEtapaColor() : Colors.white30,
            shape: BoxShape.circle),
      );

  Widget _line(bool active) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 14,
        height: 1.5,
        color: active ? _getEtapaColor() : Colors.white30,
      );

  Widget _buildTopBar() => Positioned(
        top: 12,
        left: 12,
        right: 12,
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _glassButton(icon: Icons.close_rounded, onTap: widget.onCancel),
          _stepIndicator(),
          _glassButton(
              icon: Icons.help_outline_rounded, onTap: _showHelpDialog),
        ]),
      );

  Widget _buildInstructions() => Positioned(
        top: 64,
        left: 16,
        right: 16,
        child: _glassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(_getEtapaIcon(), color: _getEtapaColor(), size: 16),
              const SizedBox(width: 6),
              Text(_getEtapaTitle(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Text(_getEtapaInstructions(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    height: 1.3)),
          ]),
        ),
      );

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Column(children: [
        _zoomSlider(),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_hasFlash && !_isFrontCamera)
            _glassButton(
                icon: _isFlashOn
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                onTap: _toggleFlash),
          const SizedBox(width: 18),
          _captureButton(),
          const SizedBox(width: 18),
          const SizedBox(width: 36), // spacer
        ]),
      ]),
    );
  }

  Widget _zoomSlider() => _glassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.zoom_out_rounded, color: Colors.white70, size: 14),
          SizedBox(
            width: 90,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: _zoomLevel.clamp(_minZoom, _maxZoom),
                min: _minZoom,
                max: _maxZoom > _minZoom ? _maxZoom : _minZoom + 0.01,
                activeColor: _getEtapaColor(),
                inactiveColor: Colors.white24,
                onChanged: (_minZoom >= _maxZoom)
                    ? null
                    : (value) async {
                        setState(() => _zoomLevel = value);
                        try {
                          await _controller.setZoomLevel(value);
                        } catch (_) {}
                      },
              ),
            ),
          ),
          const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 14),
        ]),
      );

  Widget _captureButton() => GestureDetector(
        onTap: _handleCapture,
        child: AnimatedScale(
          scale: _isCapturing ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _getEtapaColor(), width: 3.5),
              boxShadow: [
                BoxShadow(
                    color: _getEtapaColor().withOpacity(0.45),
                    blurRadius: 20,
                    spreadRadius: 2)
              ],
            ),
            child: Icon(Icons.camera_alt_rounded,
                color: _getEtapaColor(), size: 28),
          ),
        ),
      );

  Widget _buildCaptureAnimation() => Positioned.fill(
        child: IgnorePointer(
          child: Container(
            color: Colors.black.withOpacity(0.65),
            child: Center(
              child: TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                builder: (_, value, __) => Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                        color: _success, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 40),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> _handleCapture() async {
    if (_isCapturing || _isDisposed) return;
    try {
      HapticFeedback.mediumImpact();
      setState(() => _isCapturing = true);
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted && !_isDisposed) {
        setState(() => _isCapturing = false);
        widget.onCapture();
      }
    } catch (e) {
      debugPrint('Error al capturar: $e');
      if (mounted && !_isDisposed) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al capturar foto'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_isFrontCamera || _isDisposed || !_hasFlash) return;
    try {
      final newState = !_isFlashOn;
      await _controller
          .setFlashMode(newState ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _isFlashOn = newState);
    } catch (e) {
      debugPrint('Error al cambiar flash: $e');
      if (mounted) setState(() => _isFlashOn = false);
    }
  }

  void _showHelpDialog() {
    if (_isDisposed || !mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.help_rounded, color: _getEtapaColor()),
          const SizedBox(width: 10),
          const Text('Consejos', style: TextStyle(color: Colors.white))
        ]),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_getEtapaInstructions(),
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 10),
              if (widget.etapaFoto == 'frontal')
                const Text('💡 Busca buena iluminación y fondo limpio',
                    style: TextStyle(color: Colors.orange, fontSize: 12)),
              if (widget.etapaFoto == 'gesto')
                const Text('💡 Realiza el gesto de forma natural',
                    style: TextStyle(color: _warning, fontSize: 12)),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  Text('Entendido', style: TextStyle(color: _getEtapaColor()))),
        ],
      ),
    );
  }

  int _getCurrentStep() => widget.etapaFoto == 'frontal'
      ? 1
      : widget.etapaFoto == 'gesto'
          ? 2
          : 3;
  String _getEtapaTitle() => widget.etapaFoto == 'frontal'
      ? 'Frontal'
      : widget.etapaFoto == 'gesto'
          ? 'Gesto'
          : 'Constancia';
  String _getEtapaInstructions() => widget.etapaFoto == 'gesto'
      ? widget.instruccionGesto(widget.gestoSolicitado ?? '')
      : widget.etapaFoto == 'frontal'
          ? 'Centra tu rostro dentro del marco'
          : 'Captura el entorno';
  Color _getEtapaColor() => widget.etapaFoto == 'frontal'
      ? _primary
      : widget.etapaFoto == 'gesto'
          ? _warning
          : _info;
  IconData _getEtapaIcon() => widget.etapaFoto == 'frontal'
      ? Icons.face_rounded
      : widget.etapaFoto == 'gesto'
          ? Icons.pan_tool_rounded
          : Icons.photo_camera_rounded;
}

class _HolePainter extends CustomPainter {
  final double frameWidth;
  final double frameHeight;
  const _HolePainter({required this.frameWidth, required this.frameHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.45)
      ..style = PaintingStyle.fill;
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final center = Offset(size.width / 2, size.height / 2);
    final rect =
        Rect.fromCenter(center: center, width: frameWidth, height: frameHeight);
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)));
    final finalPath = Path.combine(PathOperation.difference, path, holePath);
    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant _HolePainter oldDelegate) =>
      oldDelegate.frameWidth != frameWidth ||
      oldDelegate.frameHeight != frameHeight;
}
