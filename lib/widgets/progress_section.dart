// widgets/progress_section.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

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
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: _progress).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(ProgressSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.capturasRealizadas != widget.capturasRealizadas) {
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: _progress,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        ),
      );
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double get _progress => widget.capturasRealizadas / widget.totalCapturas;

  // Colores iOS 17 modernos
  static const Color _iosBlue = Color(0xFF007AFF);
  static const Color _iosGreen = Color(0xFF34C759);
  static const Color _iosOrange = Color(0xFFFF9500);
  static const Color _iosPurple = Color(0xFFAF52DE);
  static const Color _iosPink = Color(0xFFFF2D55);
  static const Color _iosRed = Color(0xFFFF3B30);
  static const Color _iosGray = Color(0xFF8E8E93);
  static const Color _iosLightGray = Color(0xFFE5E5EA);
  static const Color _iosLabel = Color(0xFF1C1C1E);
  static const Color _iosSecondaryLabel = Color(0xFF3A3A3C);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _iosLightGray, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── CABECERA COMPACTA ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.gauge_badge_plus,
                    color: _getGradientColors().first,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Progreso',
                    style: TextStyle(
                      color: _iosLabel,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              // Contador pequeño
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getGradientColors().first.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.capturasRealizadas}/${widget.totalCapturas}',
                  style: TextStyle(
                    color: _getGradientColors().first,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // ─── BARRA DE PROGRESO COMPACTA ───
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: _iosLightGray,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        height: 4,
                        width: constraints.maxWidth * _progressAnimation.value,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _getGradientColors(),
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  _getGradientColors().first.withOpacity(0.2),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),

          // ─── INFORMACIÓN COMPACTA ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Fase actual
              Row(
                children: [
                  Icon(
                    CupertinoIcons.square_grid_2x2,
                    size: 10,
                    color: _iosGray,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${widget.posicionActual + 1}/${widget.totalPosiciones}',
                    style: TextStyle(
                      color: _iosSecondaryLabel,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // Calidad promedio
              if (widget.calidadPromedio > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getCalidadColor().withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.star_fill,
                        size: 8,
                        color: _getCalidadColor(),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${widget.calidadPromedio}%',
                        style: TextStyle(
                          color: _getCalidadColor(),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              // Estado compacto
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getEstadoColor().withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _getEstadoColor().withOpacity(0.12),
                    width: 0.3,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getEstadoIcono(),
                      size: 9,
                      color: _getEstadoColor(),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _getEstadoTexto(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: _getEstadoColor(),
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

  // ─── MÉTODOS AUXILIARES ───

  List<Color> _getGradientColors() {
    final progress = _progressAnimation.value;
    if (progress < 0.3) {
      return [_iosBlue, _iosPurple];
    } else if (progress < 0.6) {
      return [_iosPurple, _iosPink];
    } else if (progress < 0.9) {
      return [_iosPink, _iosOrange];
    } else {
      return [_iosOrange, _iosRed];
    }
  }

  Color _getCalidadColor() {
    if (widget.calidadPromedio >= 80) return _iosGreen;
    if (widget.calidadPromedio >= 60) return _iosOrange;
    return _iosRed;
  }

  Color _getEstadoColor() {
    if (_progress >= 1.0) return _iosGreen;
    if (_progress >= 0.3) return _iosBlue;
    return _iosOrange;
  }

  IconData _getEstadoIcono() {
    if (_progress >= 1.0) return CupertinoIcons.checkmark_circle_fill;
    if (_progress >= 0.3) return CupertinoIcons.hourglass;
    return CupertinoIcons.clock;
  }

  String _getEstadoTexto() {
    if (_progress >= 1.0) return 'Completado';
    if (_progress >= 0.3) return 'Progreso';
    return 'Iniciando';
  }
}
