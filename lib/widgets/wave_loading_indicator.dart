// widgets/wave_loading_indicator.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

class WaveLoadingIndicator extends StatefulWidget {
  final String message;
  final double progress;

  const WaveLoadingIndicator({
    super.key,
    this.message = 'Cargando...',
    this.progress = 0.0,
  });

  @override
  State<WaveLoadingIndicator> createState() => _WaveLoadingIndicatorState();
}

class _WaveLoadingIndicatorState extends State<WaveLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Círculo giratorio
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.deepPurple.shade600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Barra de progreso con ondas
          SizedBox(
            width: 200,
            child: WaveProgressBar(
              progress: widget.progress,
              color: Colors.deepPurple.shade600,
              height: 6,
            ),
          ),
          const SizedBox(height: 8),
          // Porcentaje
          Text(
            '${(widget.progress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// WIDGET: BARRA DE PROGRESO CON ONDAS
// ============================================
class WaveProgressBar extends StatefulWidget {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double height;

  const WaveProgressBar({
    super.key,
    required this.progress,
    this.color = Colors.deepPurple,
    this.backgroundColor = Colors.grey,
    this.height = 6,
  });

  @override
  State<WaveProgressBar> createState() => _WaveProgressBarState();
}

class _WaveProgressBarState extends State<WaveProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.height / 2),
        child: Stack(
          children: [
            // Fondo
            Container(
              width: double.infinity,
              height: widget.height,
              color: widget.backgroundColor.withOpacity(0.2),
            ),
            // Barra con ondas
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _WaveProgressPainter(
                    progress: widget.progress.clamp(0.0, 1.0),
                    color: widget.color,
                    backgroundColor: widget.backgroundColor,
                    animationValue: _controller.value,
                  ),
                  size: Size(
                    double.infinity,
                    widget.height,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double animationValue;

  _WaveProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final fillWidth = width * progress;

    if (progress <= 0) return;

    // Pintar la barra base
    final basePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(0, 0, fillWidth, height);
    canvas.drawRect(rect, basePaint);

    // Pintar el efecto de ondas
    final wavePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Crear la ruta de la onda
    final path = Path();
    final waveHeight = height * 0.6;
    final waveLength = width * 0.3;

    path.moveTo(0, height);

    // Generar ondas solo en el área llena
    for (double x = 0; x <= fillWidth + waveLength; x += 1) {
      final y = height / 2 +
          math.sin((x / waveLength) * 2 * math.pi +
                  animationValue * 2 * math.pi) *
              waveHeight +
          math.sin((x / (waveLength * 0.5)) * 2 * math.pi +
                  animationValue * 3 * math.pi) *
              (waveHeight * 0.3);

      path.lineTo(x, y);
    }

    path.lineTo(fillWidth + waveLength, height);
    path.close();

    canvas.drawPath(path, wavePaint);

    // Efecto de brillo en el borde derecho
    if (progress < 1.0) {
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..style = PaintingStyle.fill;

      final glowRect = Rect.fromLTWH(
        fillWidth - 2,
        0,
        4,
        height,
      );
      canvas.drawRect(glowRect, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}
