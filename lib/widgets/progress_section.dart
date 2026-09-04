// widgets/progress_section.dart
import 'package:flutter/material.dart';

class ProgressSection extends StatefulWidget {
  final int capturasRealizadas;
  final int totalCapturas;
  final int posicionActual;
  final int totalPosiciones;
  final int calidadPromedio;

  const ProgressSection({
    super.key,
    required this.capturasRealizadas,
    required this.totalCapturas,
    required this.posicionActual,
    required this.totalPosiciones,
    required this.calidadPromedio,
  });

  @override
  State<ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<ProgressSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();

    // Un solo controller para ambas animaciones
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Animación de pulso (va y viene)
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.8).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    // Animación de escaneo (lineal)
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double get _progress => widget.capturasRealizadas / widget.totalCapturas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.timeline, color: Colors.deepPurple[300], size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Progreso',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                '${widget.capturasRealizadas} / ${widget.totalCapturas}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ═══ BARRA FUTURISTA CON ANIMACIONES ═══
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final pulseValue = _pulseAnimation.value;
              final scanValue = _scanAnimation.value;

              return Stack(
                children: [
                  // Fondo de la barra
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  // Barra de progreso con efecto neón
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 8,
                          width: constraints.maxWidth * _progress,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.deepPurple.shade400,
                                Colors.pink.shade400,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                            boxShadow: [
                              // Sombra neón pulsante
                              BoxShadow(
                                color: Colors.deepPurple.shade500.withOpacity(
                                  0.4 + (0.3 * (pulseValue - 1.0) / 0.8),
                                ),
                                blurRadius: 10 + (8 * (pulseValue - 1.0) / 0.8),
                                spreadRadius:
                                    1 + (2 * (pulseValue - 1.0) / 0.8),
                              ),
                              BoxShadow(
                                color: Colors.blue.shade400.withOpacity(
                                  0.2 + (0.2 * (pulseValue - 1.0) / 0.8),
                                ),
                                blurRadius:
                                    15 + (10 * (pulseValue - 1.0) / 0.8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Punto pulsante
                              Transform.scale(
                                scale: 0.6 + (0.4 * (pulseValue - 1.0) / 0.8),
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.shade400.withOpacity(
                                          0.6 +
                                              (0.4 * (pulseValue - 1.0) / 0.8),
                                        ),
                                        blurRadius: 12 +
                                            (10 * (pulseValue - 1.0) / 0.8),
                                        spreadRadius:
                                            3 + (4 * (pulseValue - 1.0) / 0.8),
                                      ),
                                      BoxShadow(
                                        color: Colors.deepPurple.shade500
                                            .withOpacity(
                                          0.4 +
                                              (0.3 * (pulseValue - 1.0) / 0.8),
                                        ),
                                        blurRadius: 20 +
                                            (15 * (pulseValue - 1.0) / 0.8),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
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

                  // Efecto de escaneo (línea brillante que se mueve)
                  if (_progress > 0)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final scanPosition =
                            scanValue * constraints.maxWidth * _progress;
                        return Positioned(
                          left: scanPosition - 1,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withOpacity(0.9),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // Efecto de partículas (puntos brillantes aleatorios)
                  if (_progress > 0 && _progress < 1)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: ParticlePainter(
                            progress: _progress,
                            animation: pulseValue,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // ═══ FIN BARRA FUTURISTA ═══

          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fase ${widget.posicionActual + 1} de ${widget.totalPosiciones}',
                style: TextStyle(
                  color: Colors.deepPurple[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.calidadPromedio > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.calidadPromedio > 70
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.calidadPromedio > 70
                            ? Icons.star
                            : Icons.star_half,
                        size: 12,
                        color: widget.calidadPromedio > 70
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Calidad ${widget.calidadPromedio}%',
                        style: TextStyle(
                          color: widget.calidadPromedio > 70
                              ? Colors.green
                              : Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══ PAINTER PARA PARTÍCULAS ═══
class ParticlePainter extends CustomPainter {
  final double progress;
  final double animation;
  final List<_Particle> particles;

  ParticlePainter({required this.progress, required this.animation})
      : particles = List.generate(8, (index) {
          final random = DateTime.now().millisecondsSinceEpoch % 1000 + index;
          return _Particle(
            position: (random % 100) / 100,
            size: 1.5 + (random % 3),
            speed: 0.5 + (random % 5) / 10,
            offset: (random % 200) / 1000,
          );
        });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3 + (0.2 * (animation - 1.0) / 0.8))
      ..style = PaintingStyle.fill;

    for (var particle in particles) {
      final x =
          (particle.position + animation * particle.speed + particle.offset) %
              1.0;
      if (x <= progress) {
        final dx = x * size.width;
        final dy = size.height / 2 +
            (particle.position - 0.5) * size.height * 0.8 +
            (animation * 0.1);

        canvas.drawCircle(
          Offset(dx, dy),
          particle.size * (0.5 + 0.5 * (animation - 1.0) / 0.8),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

class _Particle {
  final double position;
  final double size;
  final double speed;
  final double offset;

  _Particle({
    required this.position,
    required this.size,
    required this.speed,
    required this.offset,
  });
}
