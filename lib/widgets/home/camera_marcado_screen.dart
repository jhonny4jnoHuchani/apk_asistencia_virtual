import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'guia_rostro_animada.dart';

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
  bool _showFocusPoint = false;
  Offset _focusPoint = Offset.zero;
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
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.995, end: 1.005).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
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
        await _controller.setFocusMode(FocusMode.auto);
      }
    } catch (e) {
      debugPrint('Lifecycle error: $e');
    }
  }

  Future<void> _initCamera() async {
    if (_isDisposed || !mounted) return;
    setState(() => _isInitializing = true);

    try {
      if (!_controller.value.isInitialized) await _controller.initialize();

      _minZoom = await _controller.getMinZoomLevel();
      _maxZoom = await _controller.getMaxZoomLevel();
      _zoomLevel = _minZoom;
      _hasFlash = !_isFrontCamera;

      await _controller.setFocusMode(FocusMode.auto);
      await _controller.setExposureMode(ExposureMode.auto);

      if (mounted && !_isDisposed) setState(() => _isInitializing = false);
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
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Error de cámara',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: const Text('Verifica permisos en Ajustes > TuApp > Cámara.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onCancel();
              },
              child: Text('Salir', style: TextStyle(color: _primary))),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_isCapturing) return false;
    if (widget.etapaFoto != 'frontal') {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('¿Cancelar marcado?',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          content: const Text('Se perderán las fotos tomadas hasta ahora.',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Continuar', style: TextStyle(color: _primary))),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salir',
                    style: TextStyle(color: Color(0xFFFF453A)))),
          ],
        ),
      );
      if (confirmar != true) return false;
    }
    widget.onCancel();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onWillPop();
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_cameraError) return _buildErrorScreen();
    if (_isInitializing || !_controller.value.isInitialized)
      return _buildLoadingScreen();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraWithOverlay(),
          SafeArea(
            child: Stack(
              children: [
                _buildTopBar(),
                _buildInstructions(),
                _buildBottomControls(),
              ],
            ),
          ),
          if (_showFocusPoint) _buildFocusIndicator(),
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
                          Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.12),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt_outlined,
                                  color: Colors.red, size: 52)),
                          const SizedBox(height: 24),
                          const Text('No se pudo acceder a la cámara',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          const Text('Revisa los permisos en Ajustes',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 14)),
                          const SizedBox(height: 28),
                          FilledButton(
                              onPressed: widget.onCancel,
                              style: FilledButton.styleFrom(
                                  backgroundColor: _primary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16))),
                              child: const Text('Volver'))
                        ])))));
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                  color: _getEtapaColor(), strokeWidth: 2.5)),
          const SizedBox(height: 18),
          Text('Preparando cámara...',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(_getEtapaTitle(),
              style: TextStyle(
                  color: _getEtapaColor(),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2)),
        ])));
  }

  Widget _buildCameraWithOverlay() {
    final size = MediaQuery.of(context).size;
    final frameSize = (size.width * 0.82).clamp(230.0, 330.0);
    final frameW = frameSize;
    final frameH = frameSize * 1.333;

    return GestureDetector(
      onTapDown: _onTapToFocus,
      child: Stack(children: [
        Positioned.fill(
            child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: ClipRect(child: CameraPreview(_controller)))),
        CustomPaint(
            painter: _HolePainter(frameWidth: frameW, frameHeight: frameH),
            child: Container()),
        if (widget.etapaFoto == 'frontal' || widget.etapaFoto == 'gesto')
          Center(child: _buildAnimatedFrame(frameW, frameH)),
      ]),
    );
  }

  Future<void> _onTapToFocus(TapDownDetails details) async {
    if (_isDisposed) return;
    final size = MediaQuery.of(context).size;
    final x = details.localPosition.dx / size.width;
    final y = details.localPosition.dy / size.height;
    setState(() {
      _showFocusPoint = true;
      _focusPoint = details.localPosition;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showFocusPoint = false);
    });
    try {
      HapticFeedback.selectionClick();
      await _controller.setFocusPoint(Offset(x, y));
      await _controller.setExposurePoint(Offset(x, y));
    } catch (_) {}
  }

  Widget _buildFocusIndicator() {
    return Positioned(
        left: _focusPoint.dx - 28,
        top: _focusPoint.dy - 28,
        child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 1.2),
                borderRadius: BorderRadius.circular(10))));
  }

  Widget _buildAnimatedFrame(double w, double h) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) => Transform.scale(
        scale: _pulseAnimation.value,
        child: SizedBox(
            width: w,
            height: h,
            child: Stack(children: [
              // Borde único y fino — minimalista
              Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: _getEtapaColor().withOpacity(0.55),
                          width: 1.2))),
              _buildGuideLines(w, h),
              // Silueta del rostro: quieta en la frontal, animada en el gesto
              Center(
                  child: GuiaRostroAnimada(
                      gesto: widget.etapaFoto == 'gesto'
                          ? widget.gestoSolicitado
                          : null,
                      ancho: w * 0.9,
                      color: Colors.white,
                      espejo: _isFrontCamera)),
              _buildCorner(Alignment.topLeft),
              _buildCorner(Alignment.topRight),
              _buildCorner(Alignment.bottomLeft),
              _buildCorner(Alignment.bottomRight),
              if (widget.etapaFoto == 'gesto' && widget.gestoSolicitado != null)
                Positioned(
                    bottom: 14,
                    left: 14,
                    right: 14,
                    child: _buildGestoIndicator()),
            ])),
      ),
    );
  }

  Widget _buildGestoIndicator() {
    return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: _warning.withOpacity(0.4), width: 1)),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.pan_tool_rounded, color: _warning, size: 15),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(
                        widget.instruccionGesto(widget.gestoSolicitado!),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)))
              ]),
            )));
  }

  Widget _buildGuideLines(double w, double h) {
    final c = Colors.white.withOpacity(0.06);
    return Stack(children: [
      Positioned(
          top: h * 0.33,
          left: 24,
          right: 24,
          child: Container(height: 0.8, color: c)),
      Positioned(
          top: h * 0.66,
          left: 24,
          right: 24,
          child: Container(height: 0.8, color: c)),
      Positioned(
          left: w * 0.33,
          top: 24,
          bottom: 24,
          child: Container(width: 0.8, color: c)),
      Positioned(
          left: w * 0.66,
          top: 24,
          bottom: 24,
          child: Container(width: 0.8, color: c)),
    ]);
  }

  Widget _buildCorner(Alignment a) {
    final color = _getEtapaColor();
    return Align(
        alignment: a,
        child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              border: Border(
                  left: a.x < 0
                      ? BorderSide(color: color, width: 3)
                      : BorderSide.none,
                  right: a.x > 0
                      ? BorderSide(color: color, width: 3)
                      : BorderSide.none,
                  top: a.y < 0
                      ? BorderSide(color: color, width: 3)
                      : BorderSide.none,
                  bottom: a.y > 0
                      ? BorderSide(color: color, width: 3)
                      : BorderSide.none),
              borderRadius: _getBorderRadius(a),
            )));
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

  /// Glass container minimalista — blur suave, sin bordes visibles
  Widget _glass({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: padding ?? const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.08), width: 0.8)),
              child: child,
            )));
  }

  Widget _glassButton(
          {required IconData icon,
          required VoidCallback onTap,
          Color? iconColor}) =>
      Material(
          color: Colors.transparent,
          child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              borderRadius: BorderRadius.circular(18),
              child: _glass(
                  child:
                      Icon(icon, color: iconColor ?? Colors.white, size: 21))));

  Widget _stepIndicator() => _glass(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _dot(_getCurrentStep() >= 1),
        _line(_getCurrentStep() >= 2),
        _dot(_getCurrentStep() >= 2),
        _line(_getCurrentStep() >= 3),
        _dot(_getCurrentStep() >= 3),
      ]));

  Widget _dot(bool active) => AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 7 : 5,
      height: active ? 7 : 5,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
          color: active ? _getEtapaColor() : Colors.white30,
          shape: BoxShape.circle));

  Widget _line(bool active) => AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 14,
      height: 1.5,
      color: active ? _getEtapaColor() : Colors.white24);

  Widget _buildTopBar() => Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _glassButton(icon: Icons.close_rounded, onTap: _onWillPop),
        _stepIndicator(),
        _glassButton(icon: Icons.help_outline_rounded, onTap: _showHelpDialog),
      ]));

  /// Instrucciones minimalistas — sin fondo pesado, solo texto sobre blur sutil
  Widget _buildInstructions() => Positioned(
      top: 72,
      left: 24,
      right: 24,
      child: _glass(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(_getEtapaIcon(), color: _getEtapaColor(), size: 15),
              const SizedBox(width: 8),
              Text(_getEtapaTitle(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2)),
            ]),
            const SizedBox(height: 6),
            Text(_getEtapaInstructions(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w400)),
          ])));

  // ========================================================
  // CONTROLES INFERIORES — BOTÓN DE CAPTURA CENTRADO REAL
  // ========================================================
  // Usamos Stack + Align(center) para que el botón de captura
  // quede perfectamente centrado, sin importar cuántos botones
  // laterales existan (flash, cambio de cámara, etc.).
  Widget _buildBottomControls() {
    return Positioned(
      bottom: 22,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom slider (solo si hay rango útil)
          if (_maxZoom > _minZoom + 0.01) ...[
            _zoomSlider(),
            const SizedBox(height: 18),
          ],
          // Fila de controles con botón central perfectamente centrado
          SizedBox(
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Botón de captura — SIEMPRE al centro exacto
                _captureButton(),
                // Botón flash — anclado a la izquierda del centro
                if (_hasFlash && !_isFrontCamera)
                  Positioned(
                    right: MediaQuery.of(context).size.width / 2 + 60,
                    child: _glassButton(
                        icon: _isFlashOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        onTap: _toggleFlash,
                        iconColor: _isFlashOn ? _warning : Colors.white),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoomSlider() => Center(
      child: _glass(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.zoom_out_rounded, color: Colors.white60, size: 14),
            SizedBox(
                width: 110,
                child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: SliderComponentShape.noOverlay,
                        activeTrackColor: _getEtapaColor(),
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white),
                    child: Slider(
                        value: _zoomLevel.clamp(_minZoom, _maxZoom),
                        min: _minZoom,
                        max: _maxZoom > _minZoom ? _maxZoom : _minZoom + 0.01,
                        onChanged: (_minZoom >= _maxZoom)
                            ? null
                            : (v) async {
                                setState(() => _zoomLevel = v);
                                try {
                                  await _controller.setZoomLevel(v);
                                } catch (_) {}
                              }))),
            const Icon(Icons.zoom_in_rounded, color: Colors.white60, size: 14),
          ])));

  /// Botón de captura minimalista — anillo blanco con relleno según etapa
  Widget _captureButton() => GestureDetector(
        onTap: _handleCapture,
        child: AnimatedScale(
          scale: _isCapturing ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            padding: const EdgeInsets.all(5),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getEtapaColor(),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Colors.white, size: 28),
            ),
          ),
        ),
      );

  Widget _buildCaptureAnimation() => Positioned.fill(
      child: IgnorePointer(
          child: Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                  child: TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutBack,
                      builder: (_, v, __) => Transform.scale(
                          scale: v,
                          child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                  color: _success, shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 42))))))));

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Error al capturar foto'),
            backgroundColor: Colors.red));
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
      if (mounted) setState(() => _isFlashOn = false);
    }
  }

  void _showHelpDialog() {
    if (_isDisposed || !mounted) return;
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              title: Row(children: [
                Icon(Icons.help_rounded, color: _getEtapaColor(), size: 20),
                const SizedBox(width: 10),
                const Text('Consejos',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600))
              ]),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_getEtapaInstructions(),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13.5,
                            height: 1.4)),
                    const SizedBox(height: 14),
                    if (widget.etapaFoto == 'frontal')
                      _helpTip('Busca buena iluminación natural'),
                    if (widget.etapaFoto == 'gesto')
                      _helpTip('Realiza el gesto de forma clara'),
                    if (widget.etapaFoto == 'constancia')
                      _helpTip('Encuadra el entorno completo'),
                  ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Entendido',
                        style: TextStyle(color: _getEtapaColor())))
              ],
            ));
  }

  Widget _helpTip(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lightbulb_outline_rounded, color: _warning, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12.5, height: 1.3))),
      ]));

  int _getCurrentStep() => widget.etapaFoto == 'frontal'
      ? 1
      : widget.etapaFoto == 'gesto'
          ? 2
          : 3;
  String _getEtapaTitle() => widget.etapaFoto == 'frontal'
      ? 'Foto Frontal'
      : widget.etapaFoto == 'gesto'
          ? 'Verificación de Gesto'
          : 'Foto de Constancia';
  String _getEtapaInstructions() => widget.etapaFoto == 'gesto'
      ? widget.instruccionGesto(widget.gestoSolicitado ?? '')
      : widget.etapaFoto == 'frontal'
          ? 'Centra tu rostro dentro del marco'
          : 'Captura el entorno donde te encuentras';
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
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final center = Offset(size.width / 2, size.height / 2);
    final rect =
        Rect.fromCenter(center: center, width: frameWidth, height: frameHeight);
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)));
    final finalPath = Path.combine(PathOperation.difference, path, holePath);
    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant _HolePainter oldDelegate) =>
      oldDelegate.frameWidth != frameWidth ||
      oldDelegate.frameHeight != frameHeight;
}
