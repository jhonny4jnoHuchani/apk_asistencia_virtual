import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/horario.dart';
import 'package:flutter/cupertino.dart';

class HorarioCardExtended extends StatefulWidget {
  final Horario horario;
  final VoidCallback onMarcarEntrada;
  final VoidCallback onMarcarSalida;

  const HorarioCardExtended({
    super.key,
    required this.horario,
    required this.onMarcarEntrada,
    required this.onMarcarSalida,
  });

  @override
  State<HorarioCardExtended> createState() => _HorarioCardExtendedState();
}

class _HorarioCardExtendedState extends State<HorarioCardExtended> {
  late Timer _timer;

  // Tiempos para entrada
  Duration _tiempoRestanteEntrada = Duration.zero;
  Duration _tiempoRetrasoEntrada = Duration.zero;
  bool _puedeMarcarEntrada = false;

  // Tiempos para salida
  Duration _tiempoRestanteSalida = Duration.zero;
  Duration _tiempoRetrasoSalida = Duration.zero;
  bool _puedeMarcarSalida = false;

  double _progreso = 0.0;
  bool _mostrarTemporizadorSalida = false;

  // Colores iOS
  static const Color _iosBlue = Color.fromARGB(255, 0, 132, 255);
  static const Color _iosGreen = Color(0xFF34C759);
  static const Color _iosOrange = Color(0xFFFF9500);
  static const Color _iosRed = Color(0xFFFF3B30);
  static const Color _iosYellow = Color(0xFFFFCC00);
  static const Color _iosGray = Color(0xFF8E8E93);
  static const Color _iosLightGray = Color(0xFFF2F2F7);
  static const Color _iosSeparator = Color(0xFFE5E5EA);
  static const Color _iosBackground = Color(0xFFF2F2F7);
  static const Color _iosLabel = Color(0xFF000000);
  static const Color _iosSecondaryLabel = Color(0xFF3C3C43);

  @override
  void initState() {
    super.initState();
    _calcularTiempos();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calcularTiempos();
    });
  }

  void _calcularTiempos() {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    final horaInicioParts = widget.horario.horaInicio.split(':');
    final horaFinParts = widget.horario.horaFin.split(':');

    final inicio = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
      int.parse(horaInicioParts[0]),
      int.parse(horaInicioParts[1]),
    );

    final fin = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
      int.parse(horaFinParts[0]),
      int.parse(horaFinParts[1]),
    );

    // Calcular progreso (0-1) entre inicio y fin
    final totalDuracion = fin.difference(inicio);
    final transcurrido = ahora.difference(inicio);
    double progreso = 0.0;
    if (totalDuracion.inSeconds > 0 && !widget.horario.yaMarcoEntrada) {
      progreso =
          (transcurrido.inSeconds / totalDuracion.inSeconds).clamp(0.0, 1.0);
    } else if (widget.horario.yaMarcoEntrada && !widget.horario.yaMarcoSalida) {
      final salidaTranscurrido = ahora.difference(fin);
      final maxDuracion = const Duration(minutes: 30);
      progreso = (salidaTranscurrido.inSeconds / maxDuracion.inSeconds)
          .clamp(0.0, 1.0);
    }

    setState(() {
      _progreso = progreso;

      // ============================================
      // CÁLCULOS PARA ENTRADA
      // ============================================

      // Tiempo restante para entrada
      if (ahora.isBefore(inicio)) {
        _tiempoRestanteEntrada = inicio.difference(ahora);
        _tiempoRetrasoEntrada = Duration.zero;
      } else if (ahora.isAfter(inicio) && !widget.horario.yaMarcoEntrada) {
        _tiempoRestanteEntrada = Duration.zero;
        _tiempoRetrasoEntrada = ahora.difference(inicio);
      } else {
        _tiempoRestanteEntrada = Duration.zero;
        _tiempoRetrasoEntrada = Duration.zero;
      }

      // Rango para entrada: 30 minutos antes y 150 minutos después
      final entradaAntes = inicio.subtract(const Duration(minutes: 30));
      final entradaDespues = inicio.add(const Duration(minutes: 150));

      _puedeMarcarEntrada = !widget.horario.yaMarcoEntrada &&
          ahora.isAfter(entradaAntes) &&
          ahora.isBefore(entradaDespues);

      // ============================================
      // CÁLCULOS PARA SALIDA
      // ============================================

      _mostrarTemporizadorSalida =
          widget.horario.yaMarcoEntrada && !widget.horario.yaMarcoSalida;

      if (_mostrarTemporizadorSalida) {
        if (ahora.isBefore(fin)) {
          _tiempoRestanteSalida = fin.difference(ahora);
          _tiempoRetrasoSalida = Duration.zero;
        } else if (ahora.isAfter(fin)) {
          _tiempoRestanteSalida = Duration.zero;
          _tiempoRetrasoSalida = ahora.difference(fin);
        } else {
          _tiempoRestanteSalida = Duration.zero;
          _tiempoRetrasoSalida = Duration.zero;
        }
      } else {
        _tiempoRestanteSalida = Duration.zero;
        _tiempoRetrasoSalida = Duration.zero;
      }

      // Rango para salida: desde 30 minutos antes hasta 30 minutos después
      final salidaAntes = fin.subtract(const Duration(minutes: 30));
      final salidaDespues = fin.add(const Duration(minutes: 30));

      _puedeMarcarSalida = widget.horario.yaMarcoEntrada &&
          !widget.horario.yaMarcoSalida &&
          ahora.isAfter(salidaAntes) &&
          ahora.isBefore(salidaDespues);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatearTiempo(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  // ============================================
  // MÉTODOS PARA ENTRADA
  // ============================================

  Color _getColorEstadoEntrada() {
    if (_tiempoRetrasoEntrada.inMinutes > 0) {
      final minutos = _tiempoRetrasoEntrada.inMinutes;
      if (minutos < 5) return _iosOrange;
      if (minutos < 15) return Colors.orange.shade700;
      return _iosRed;
    }
    return _iosBlue;
  }

  IconData _getIconoEntrada() {
    if (_tiempoRetrasoEntrada.inMinutes > 0) {
      return CupertinoIcons.exclamationmark_triangle;
    } else if (_tiempoRestanteEntrada.inMinutes > 0 ||
        _tiempoRestanteEntrada.inSeconds > 0) {
      return CupertinoIcons.timer;
    }
    return CupertinoIcons.checkmark_circle;
  }

  String _getTextoEntrada() {
    if (_tiempoRetrasoEntrada.inMinutes > 0) {
      final minutos = _tiempoRetrasoEntrada.inMinutes;
      final segundos = _tiempoRetrasoEntrada.inSeconds.remainder(60);
      if (minutos > 60) {
        final horas = minutos ~/ 60;
        final mins = minutos % 60;
        return 'Retraso entrada: $horas h $mins min';
      }
      return 'Retraso entrada: $minutos min $segundos s';
    } else if (_tiempoRestanteEntrada.inMinutes > 0 ||
        _tiempoRestanteEntrada.inSeconds > 0) {
      if (_tiempoRestanteEntrada.inHours > 0) {
        return 'Falta para entrada: ${_formatearTiempo(_tiempoRestanteEntrada)}';
      }
      return 'Falta para entrada: ${_formatearTiempo(_tiempoRestanteEntrada)}';
    } else if (widget.horario.yaMarcoEntrada) {
      return 'Entrada marcada';
    }
    return 'Hora de entrada';
  }

  // ============================================
  // MÉTODOS PARA SALIDA
  // ============================================

  Color _getColorEstadoSalida() {
    if (_tiempoRetrasoSalida.inMinutes > 0) {
      final minutos = _tiempoRetrasoSalida.inMinutes;
      if (minutos < 5) return _iosOrange;
      if (minutos < 15) return Colors.orange.shade700;
      return _iosRed;
    }
    return _iosRed;
  }

  IconData _getIconoSalida() {
    if (_tiempoRetrasoSalida.inMinutes > 0) {
      return CupertinoIcons.exclamationmark_triangle;
    } else if (_tiempoRestanteSalida.inMinutes > 0 ||
        _tiempoRestanteSalida.inSeconds > 0) {
      return CupertinoIcons.timer;
    }
    return CupertinoIcons.checkmark_circle;
  }

  String _getTextoSaida() {
    if (_tiempoRetrasoSalida.inMinutes > 0) {
      final minutos = _tiempoRetrasoSalida.inMinutes;
      final segundos = _tiempoRetrasoSalida.inSeconds.remainder(60);
      if (minutos > 60) {
        final horas = minutos ~/ 60;
        final mins = minutos % 60;
        return 'Retraso salida: $horas h $mins min';
      }
      return 'Retraso salida: $minutos min $segundos s';
    } else if (_tiempoRestanteSalida.inMinutes > 0 ||
        _tiempoRestanteSalida.inSeconds > 0) {
      if (_tiempoRestanteSalida.inHours > 0) {
        return 'Falta para salida: ${_formatearTiempo(_tiempoRestanteSalida)}';
      }
      return 'Falta para salida: ${_formatearTiempo(_tiempoRestanteSalida)}';
    } else if (widget.horario.yaMarcoSalida) {
      return 'Salida marcada';
    }
    return 'Hora de salida';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con estilo iOS
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getColorHeader(),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.horario.materia,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Paralelo ${widget.horario.paralelo}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge estilo iOS
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.horario.estaCompletado
                        ? 'Completado'
                        : widget.horario.yaMarcoEntrada
                            ? 'En curso'
                            : 'Pendiente',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenido
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Horario y ubicación
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.clock,
                      size: 16,
                      color: _iosGray,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.horario.horaInicio} - ${widget.horario.horaFin}',
                      style: TextStyle(
                        fontSize: 14,
                        color: _iosSecondaryLabel,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.horario.ubicacion != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.location,
                              size: 16,
                              color: _iosGray,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.horario.ubicacion!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _iosSecondaryLabel,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                // Barra de progreso iOS
                if (!widget.horario.estaCompletado) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _progreso.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: _iosLightGray,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _progreso > 0.8 ? _iosGreen : _iosBlue,
                      ),
                    ),
                  ),
                ],

                // ============================================
                // TEMPORIZADOR DE ENTRADA - iOS Style
                // ============================================
                if (!widget.horario.yaMarcoEntrada) ...[
                  const SizedBox(height: 12),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _getColorEstadoEntrada().withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _getColorEstadoEntrada().withOpacity(0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getIconoEntrada(),
                            color: _getColorEstadoEntrada(),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _getTextoEntrada(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _getColorEstadoEntrada(),
                              ),
                            ),
                          ),
                          if (_tiempoRetrasoEntrada.inMinutes > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _getColorEstadoEntrada().withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Tarde',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _getColorEstadoEntrada(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ============================================
                // TEMPORIZADOR DE SALIDA - iOS Style
                // ============================================
                if (_mostrarTemporizadorSalida) ...[
                  const SizedBox(height: 12),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _getColorEstadoSalida().withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _getColorEstadoSalida().withOpacity(0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getIconoSalida(),
                            color: _getColorEstadoSalida(),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _getTextoSaida(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _getColorEstadoSalida(),
                              ),
                            ),
                          ),
                          if (_tiempoRetrasoSalida.inMinutes > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _getColorEstadoSalida().withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Tarde',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _getColorEstadoSalida(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ============================================
                // BOTONES - iOS Style
                // ============================================
                Row(
                  children: [
                    if (!widget.horario.yaMarcoEntrada)
                      Expanded(
                        child: _buildBotonIOS(
                          texto: 'Marcar Entrada',
                          icon: CupertinoIcons.arrow_right_to_line_alt,
                          color: _iosBlue,
                          disponible: _puedeMarcarEntrada,
                          onPressed: widget.onMarcarEntrada,
                        ),
                      ),
                    if (widget.horario.yaMarcoEntrada &&
                        !widget.horario.yaMarcoSalida)
                      Expanded(
                        child: _buildBotonIOS(
                          texto: 'Marcar Salida',
                          icon: CupertinoIcons.arrow_left_to_line_alt,
                          color: _iosRed,
                          disponible: _puedeMarcarSalida,
                          onPressed: () => _mostrarDialogoSalida(context),
                        ),
                      ),
                  ],
                ),

                // Estado completado
                if (widget.horario.estaCompletado) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_iosGreen, _iosGreen.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.checkmark_circle,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Asistencia completada',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            CupertinoIcons.checkmark,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getColorHeader() {
    if (widget.horario.estaCompletado) {
      return [_iosGreen, _iosGreen.withOpacity(0.7)];
    }
    if (widget.horario.yaMarcoEntrada) {
      return [_iosYellow, _iosOrange];
    }
    return [_iosBlue, _iosBlue.withOpacity(0.7)];
  }

  // ============================================
  // BOTÓN ESTILO iOS
  // ============================================
  Widget _buildBotonIOS({
    required String texto,
    required IconData icon,
    required Color color,
    required bool disponible,
    required VoidCallback onPressed,
  }) {
    return CupertinoButton(
      onPressed: disponible ? onPressed : null,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: disponible ? color : _iosLightGray,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: disponible ? color : _iosSeparator,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: disponible ? Colors.white : _iosGray,
            ),
            const SizedBox(width: 6),
            Text(
              texto,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: disponible ? Colors.white : _iosGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // DIALOGO SALIDA - iOS Style
  // ============================================
  void _mostrarDialogoSalida(BuildContext context) {
    final ahora = DateTime.now();
    final horaFinParts = widget.horario.horaFin.split(':');
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final fin = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
      int.parse(horaFinParts[0]),
      int.parse(horaFinParts[1]),
    );

    final diferencia = ahora.difference(fin);
    final minutosDiferencia = diferencia.inMinutes;

    String titulo = 'Confirmar Salida';
    String mensaje = '¿Desea marcar su salida ahora?';
    Color color = _iosBlue;
    IconData icono = CupertinoIcons.arrow_right_to_line_alt;

    if (minutosDiferencia < 0) {
      final minutosAntes = minutosDiferencia.abs();
      titulo = 'Salida Anticipada';
      mensaje = 'Está saliendo $minutosAntes min antes de lo programado.';
      color = minutosAntes > 15 ? _iosRed : _iosOrange;
      icono = CupertinoIcons.exclamationmark_triangle;
    } else if (minutosDiferencia <= 15) {
      titulo = 'Salida en Horario';
      mensaje = 'Está saliendo dentro del horario establecido.';
      color = _iosGreen;
      icono = CupertinoIcons.checkmark_circle;
    } else {
      titulo = 'Salida Tardía';
      mensaje =
          'Está saliendo $minutosDiferencia min después de lo programado.';
      color = _iosOrange;
      icono = CupertinoIcons.timer;
    }

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          children: [
            Icon(icono, color: color, size: 24),
            const SizedBox(width: 10),
            Text(titulo),
          ],
        ),
        content: Column(
          children: [
            const SizedBox(height: 8),
            Text(mensaje),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _iosLightGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildInfoRowIOS('Materia', widget.horario.materia),
                  _buildInfoRowIOS('Paralelo', widget.horario.paralelo),
                  _buildInfoRowIOS('Hora salida', widget.horario.horaFin),
                  _buildInfoRowIOS(
                    'Hora actual',
                    DateFormat('HH:mm').format(ahora),
                  ),
                  if (minutosDiferencia.abs() > 0)
                    _buildInfoRowIOS(
                      'Diferencia',
                      '${minutosDiferencia.abs()} min ${minutosDiferencia > 0 ? 'después' : 'antes'}',
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              widget.onMarcarSalida();
            },
            isDestructiveAction: minutosDiferencia.abs() > 15,
            child: Text(
              'Confirmar',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowIOS(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: _iosGray,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _iosLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// CARD ESTILO iOS
// ============================================
class CupertinoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;

  const CupertinoCard({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE5E5EA),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}
