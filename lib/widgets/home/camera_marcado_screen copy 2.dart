import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isCapturing = false;
  bool _isFrontCamera = true;
  double _zoomLevel = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 3.0;
  bool _isFlashOn = false;
  bool _isInitializing = true;
  bool _cameraError = false;
  bool _isDisposed = false;

  static const Color _primary = Color(0xFF007AFF);
  static const Color _warning = Color(0xFFFF9500);
  static const Color _success = Color(0xFF34C759);
  static const Color _info = Color(0xFF5AC8FA);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isFrontCamera = widget.cameraController.description.lensDirection ==
        CameraLensDirection.front;

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 100), _initCamera);
  }

  @override
  void didUpdateWidget(CameraMarcadoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraController != widget.cameraController) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    try {
      if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused) {
        _cameraController.pausePreview();
      } else if (state == AppLifecycleState.resumed) {
        _cameraController.resumePreview();
      }
    } catch (_) {}
  }

  CameraController get _cameraController => widget.cameraController;

  Future<void> _initCamera() async {
    if (_isDisposed || !mounted) return;

    setState(() => _isInitializing = true);

    try {
      if (!_cameraController.value.isInitialized) {
        await _cameraController.initialize();
      }

      try {
        _minZoom = await _cameraController.getMinZoomLevel();
        _maxZoom = await _cameraController.getMaxZoomLevel();
        _zoomLevel = _minZoom;
      } catch (_) {
        _minZoom = 1.0;
        _maxZoom = 1.0;
      }

      try {
        await _cameraController.setFocusMode(FocusMode.auto);
      } catch (_) {}

      if (mounted && !_isDisposed) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      debugPrint('Error al iniciar camara: $e');
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
          'No se pudo iniciar la cámara.\nVerifica que tengas permisos y reinicia la aplicación.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted && !_isDisposed) {
                widget.onCancel();
              }
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError) {
      return _buildErrorScreen();
    }

    if (_isInitializing || !_cameraController.value.isInitialized) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraWithOverlay(),
          _buildTopBar(),
          _buildInstructions(),
          _buildBottomControls(),
          if (_isCapturing) _buildCaptureAnimation(),
        ],
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
                const Text(
                  'Error al iniciar cámara',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Verifica los permisos y reinicia la app',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (mounted && !_isDisposed) {
                      widget.onCancel();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
            CircularProgressIndicator(color: _primary),
            SizedBox(height: 12),
            Text(
              'Iniciando cámara...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraWithOverlay() {
    final screenSize = MediaQuery.of(context).size;
    final frameSize = (screenSize.width * 0.7).clamp(220.0, 320.0);
    final frameWidth = frameSize;
    final frameHeight = frameSize * 1.333;

    return Stack(
      children: [
        Positioned.fill(
          child: AspectRatio(
            aspectRatio: _cameraController.value.aspectRatio,
            child: ClipRect(
              child: CameraPreview(_cameraController),
            ),
          ),
        ),
        CustomPaint(
          painter: _HolePainter(
            frameWidth: frameWidth,
            frameHeight: frameHeight,
          ),
          child: Container(),
        ),
        if (widget.etapaFoto == 'frontal' || widget.etapaFoto == 'gesto')
          Center(
            child: _buildAnimatedFrame(frameWidth, frameHeight),
          ),
      ],
    );
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
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _getEtapaColor().withOpacity(0.7),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getEtapaColor().withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 1,
              ),
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
                  child: _buildGestoIndicator(),
                ),
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
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _warning.withOpacity(0.2), width: 1),
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideLines(double w, double h) {
    return Stack(
      children: [
        Positioned(
          top: h * 0.3,
          left: 16,
          right: 16,
          child: Container(height: 1, color: Colors.white.withOpacity(0.06)),
        ),
        Positioned(
          top: h * 0.6,
          left: 16,
          right: 16,
          child: Container(height: 1, color: Colors.white.withOpacity(0.06)),
        ),
        Positioned(
          left: w * 0.33,
          top: 16,
          bottom: 16,
          child: Container(width: 1, color: Colors.white.withOpacity(0.06)),
        ),
        Positioned(
          left: w * 0.66,
          top: 16,
          bottom: 16,
          child: Container(width: 1, color: Colors.white.withOpacity(0.06)),
        ),
      ],
    );
  }

  Widget _buildCornerBorder(Alignment alignment) {
    final color = _getEtapaColor();
    return Align(
      alignment: alignment,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          border: Border(
            left: alignment.x < 0
                ? BorderSide(color: color, width: 3)
                : BorderSide.none,
            right: alignment.x > 0
                ? BorderSide(color: color, width: 3)
                : BorderSide.none,
            top: alignment.y < 0
                ? BorderSide(color: color, width: 3)
                : BorderSide.none,
            bottom: alignment.y > 0
                ? BorderSide(color: color, width: 3)
                : BorderSide.none,
          ),
          borderRadius: _getBorderRadius(alignment),
        ),
      ),
    );
  }

  BorderRadius _getBorderRadius(Alignment a) {
    if (a == Alignment.topLeft) {
      return const BorderRadius.only(topLeft: Radius.circular(18));
    }
    if (a == Alignment.topRight) {
      return const BorderRadius.only(topRight: Radius.circular(18));
    }
    if (a == Alignment.bottomLeft) {
      return const BorderRadius.only(bottomLeft: Radius.circular(18));
    }
    return const BorderRadius.only(bottomRight: Radius.circular(18));
  }

  Widget _buildTopBar() => Positioned(
        top: MediaQuery.of(context).padding.top + 12,
        left: 12,
        right: 12,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _glassButton(icon: Icons.close_rounded, onTap: widget.onCancel),
            _stepIndicator(),
            _glassButton(
                icon: Icons.help_outline_rounded, onTap: _showHelpDialog),
          ],
        ),
      );

  Widget _glassButton({
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            color: Colors.white.withOpacity(0.12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
      );

  Widget _stepIndicator() => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
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
          ),
        ),
      );

  Widget _dot(bool active) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: active ? _getEtapaColor() : Colors.white30,
          shape: BoxShape.circle,
        ),
      );

  Widget _line(bool active) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 14,
        height: 1.5,
        color: active ? _getEtapaColor() : Colors.white30,
      );

  Widget _buildInstructions() => Positioned(
        top: MediaQuery.of(context).padding.top + 64,
        left: 16,
        right: 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getEtapaIcon(), color: _getEtapaColor(), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _getEtapaTitle(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getEtapaInstructions(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildBottomControls() {
    final hasMultipleCameras = widget.cameras.length > 1;
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      left: 0,
      right: 0,
      child: Column(
        children: [
          _zoomSlider(),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _glassButton(
                icon: _isFlashOn
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                onTap: _toggleFlash,
              ),
              const SizedBox(width: 18),
              _captureButton(),
              const SizedBox(width: 18),
              if (hasMultipleCameras)
                _glassButton(
                  icon: Icons.cameraswitch_rounded,
                  onTap: _flipCamera,
                )
              else
                const SizedBox(width: 36),
            ],
          ),
        ],
      ),
    );
  }

  Widget _zoomSlider() => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.zoom_out_rounded,
                    color: Colors.white70, size: 14),
                SizedBox(
                  width: 80,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5,
                      ),
                    ),
                    child: Slider(
                      value: _zoomLevel,
                      min: _minZoom,
                      max: _maxZoom,
                      activeColor: _getEtapaColor(),
                      inactiveColor: Colors.white24,
                      onChanged: (value) async {
                        setState(() => _zoomLevel = value);
                        try {
                          await _cameraController.setZoomLevel(value);
                        } catch (_) {}
                      },
                    ),
                  ),
                ),
                const Icon(Icons.zoom_in_rounded,
                    color: Colors.white70, size: 14),
              ],
            ),
          ),
        ),
      );

  Widget _captureButton() => GestureDetector(
        onTap: _handleCapture,
        child: AnimatedScale(
          scale: _isCapturing ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _getEtapaColor(), width: 3),
              boxShadow: [
                BoxShadow(
                  color: _getEtapaColor().withOpacity(0.4),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.camera_alt_rounded,
              color: _getEtapaColor(),
              size: 26,
            ),
          ),
        ),
      );

  Widget _buildCaptureAnimation() => Positioned.fill(
        child: Container(
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 300),
              builder: (_, value, __) => Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _success,
                    shape: BoxShape.circle,
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
        ),
      );

  Future<void> _handleCapture() async {
    if (_isCapturing || _isDisposed) return;

    try {
      HapticFeedback.mediumImpact();
      setState(() => _isCapturing = true);
      await Future.delayed(const Duration(milliseconds: 300));
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
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _flipCamera() async {
    if (widget.cameras.length < 2 || _isDisposed) return;

    try {
      HapticFeedback.lightImpact();

      final newLensDirection =
          _isFrontCamera ? CameraLensDirection.back : CameraLensDirection.front;

      final newCamera = widget.cameras.firstWhere(
        (c) => c.lensDirection == newLensDirection,
        orElse: () => widget.cameras.first,
      );

      if (mounted && !_isDisposed) {
        setState(() => _isInitializing = true);
        await _cameraController.dispose();

        final newController = CameraController(
          newCamera,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await newController.initialize();
        _isFrontCamera = !_isFrontCamera;
        await _initCamera();
      }
    } catch (e) {
      debugPrint('Error al cambiar cámara: $e');
      if (mounted && !_isDisposed) {
        setState(() => _isInitializing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cambiar cámara'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_isFrontCamera || _isDisposed) return;

    try {
      setState(() => _isFlashOn = !_isFlashOn);
      await _cameraController.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      debugPrint('Error al cambiar flash: $e');
      setState(() => _isFlashOn = false);
    }
  }

  void _showHelpDialog() {
    if (_isDisposed || !mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.help_rounded, color: _getEtapaColor()),
            const SizedBox(width: 10),
            const Text('Consejos', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getEtapaInstructions(),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            if (widget.etapaFoto == 'frontal')
              const Text(
                '💡 Asegúrate de tener buena iluminación',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            if (widget.etapaFoto == 'gesto')
              Text(
                '💡 Realiza el gesto de forma natural',
                style: TextStyle(color: _warning, fontSize: 12),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido', style: TextStyle(color: _getEtapaColor())),
          ),
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
      ? widget.instruccionGesto(widget.gestoSolicitado!)
      : widget.etapaFoto == 'frontal'
          ? 'Centra tu rostro'
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

  const _HolePainter({
    required this.frameWidth,
    required this.frameHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: frameWidth,
      height: frameHeight,
    );
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)));

    final finalPath = Path.combine(PathOperation.difference, path, holePath);
    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
