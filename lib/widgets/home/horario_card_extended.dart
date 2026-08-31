import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/horario.dart';

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

  // Constantes de diseño
  static const Color _primaryColor = Color(0xFF5B67CA);
  static const Color _secondaryColor = Color(0xFF8B95E0);
  static const Color _successColor = Color(0xFF00B894);
  static const Color _warningColor = Color(0xFFFDCB6E);
  static const Color _dangerColor = Color(0xFFE17055);
  static const Color _textPrimary = Color(0xFF2D3436);
  static const Color _textSecondary = Color(0xFF636E72);
  static const Color _backgroundColor = Color(0xFFF8F9FC);

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

      // Rango para entrada: 30 minutos antes y 30 minutos después
      final entradaAntes = inicio.subtract(const Duration(minutes: 30));
      final entradaDespues = inicio.add(const Duration(minutes: 30));

      _puedeMarcarEntrada = !widget.horario.yaMarcoEntrada &&
          ahora.isAfter(entradaAntes) &&
          ahora.isBefore(entradaDespues);

      // ============================================
      // CÁLCULOS PARA SALIDA
      // ============================================

      // Mostrar temporizador de salida solo si ya marcó entrada
      _mostrarTemporizadorSalida =
          widget.horario.yaMarcoEntrada && !widget.horario.yaMarcoSalida;

      if (_mostrarTemporizadorSalida) {
        // Tiempo restante para salida (si es antes)
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
      if (minutos < 5) return Colors.orange.shade600;
      if (minutos < 15) return Colors.deepOrange.shade600;
      return Colors.red.shade600;
    }
    return _primaryColor;
  }

  IconData _getIconoEntrada() {
    if (_tiempoRetrasoEntrada.inMinutes > 0) {
      return Icons.warning_amber_rounded;
    } else if (_tiempoRestanteEntrada.inMinutes > 0 ||
        _tiempoRestanteEntrada.inSeconds > 0) {
      return Icons.timer_rounded;
    }
    return Icons.check_circle_rounded;
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
      if (minutos < 5) return Colors.orange.shade600;
      if (minutos < 15) return Colors.deepOrange.shade600;
      return Colors.red.shade600;
    }
    return _dangerColor;
  }

  IconData _getIconoSalida() {
    if (_tiempoRetrasoSalida.inMinutes > 0) {
      return Icons.warning_amber_rounded;
    } else if (_tiempoRestanteSalida.inMinutes > 0 ||
        _tiempoRestanteSalida.inSeconds > 0) {
      return Icons.timer_rounded;
    }
    return Icons.check_circle_rounded;
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
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A5B67CA),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con gradiente según estado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getColorHeader(),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
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
                            fontWeight: FontWeight.bold,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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
                        Icons.access_time_rounded,
                        size: 16,
                        color: _textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.horario.horaInicio} - ${widget.horario.horaFin}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (widget.horario.ubicacion != null) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: _textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.horario.ubicacion!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _textSecondary,
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

                  // Barra de progreso
                  if (!widget.horario.estaCompletado) ...[
                    const SizedBox(height: 14),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            widthFactor: _progreso.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_primaryColor, _secondaryColor],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ============================================
                  // TEMPORIZADOR DE ENTRADA
                  // ============================================
                  if (!widget.horario.yaMarcoEntrada) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _getColorEstadoEntrada().withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getColorEstadoEntrada().withOpacity(0.2),
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
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _getColorEstadoEntrada().withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Tarde',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getColorEstadoEntrada(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // ============================================
                  // TEMPORIZADOR DE SALIDA
                  // ============================================
                  if (_mostrarTemporizadorSalida) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _getColorEstadoSalida().withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getColorEstadoSalida().withOpacity(0.2),
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
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _getColorEstadoSalida().withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Tarde',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getColorEstadoSalida(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ============================================
                  // BOTONES
                  // ============================================
                  Row(
                    children: [
                      // Botón Entrada
                      if (!widget.horario.yaMarcoEntrada)
                        Expanded(
                          child: _buildBoton(
                            texto: 'Entrada',
                            icon: Icons.login_rounded,
                            color: _primaryColor,
                            disponible: _puedeMarcarEntrada,
                            onPressed: widget.onMarcarEntrada,
                            subtitulo: _puedeMarcarEntrada
                                ? null
                                : '30 min antes/despues',
                          ),
                        ),

                      // Botón Salida
                      if (widget.horario.yaMarcoEntrada &&
                          !widget.horario.yaMarcoSalida)
                        Expanded(
                          child: _buildBoton(
                            texto: 'Salida',
                            icon: Icons.logout_rounded,
                            color: _dangerColor,
                            disponible: _puedeMarcarSalida,
                            onPressed: () => _mostrarDialogoSalida(context),
                            subtitulo: _puedeMarcarSalida
                                ? null
                                : '30 min antes/despues',
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
                          colors: [
                            _successColor,
                            _successColor.withOpacity(0.7)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
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
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.check,
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
      ),
    );
  }

  List<Color> _getColorHeader() {
    if (widget.horario.estaCompletado) {
      return [const Color(0xFF00B894), const Color(0xFF00A381)];
    }
    if (widget.horario.yaMarcoEntrada) {
      return [const Color(0xFFFDCB6E), const Color(0xFFF39C12)];
    }
    return [const Color(0xFF5B67CA), const Color(0xFF8B95E0)];
  }

  Widget _buildBoton({
    required String texto,
    required IconData icon,
    required Color color,
    required bool disponible,
    required VoidCallback onPressed,
    String? subtitulo,
  }) {
    return ElevatedButton(
      onPressed: disponible ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: disponible ? color : Colors.grey.shade300,
        foregroundColor: disponible ? Colors.white : Colors.grey.shade600,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        elevation: disponible ? 2 : 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(
                texto,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitulo,
              style: TextStyle(
                fontSize: 9,
                color: disponible ? Colors.white70 : Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }

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

    String titulo = 'Confirmar salida';
    String mensaje = '¿Desea marcar su salida ahora?';
    Color color = _primaryColor;
    IconData icono = Icons.exit_to_app_rounded;

    if (minutosDiferencia < 0) {
      final minutosAntes = minutosDiferencia.abs();
      titulo = 'Salida anticipada';
      mensaje =
          'Está saliendo $minutosAntes minutos antes de la hora programada.';
      color = minutosAntes > 15 ? Colors.red.shade600 : Colors.orange.shade600;
      icono = Icons.warning_amber_rounded;
    } else if (minutosDiferencia <= 15) {
      titulo = 'Salida en horario';
      mensaje = 'Está saliendo dentro del horario establecido.';
      color = _successColor;
      icono = Icons.check_circle_rounded;
    } else {
      titulo = 'Salida tardía';
      mensaje =
          'Está saliendo $minutosDiferencia minutos después de la hora programada.';
      color = Colors.orange.shade600;
      icono = Icons.timer_rounded;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono circular
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icono,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Materia', widget.horario.materia),
                    _buildInfoRow('Paralelo', widget.horario.paralelo),
                    _buildInfoRow('Hora salida', widget.horario.horaFin),
                    _buildInfoRow(
                      'Hora actual',
                      DateFormat('HH:mm').format(ahora),
                    ),
                    if (minutosDiferencia.abs() > 0)
                      _buildInfoRow(
                        'Diferencia',
                        '${minutosDiferencia.abs()} min ${minutosDiferencia > 0 ? 'después' : 'antes'}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        foregroundColor: _textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                        widget.onMarcarSalida();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Confirmar',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: _textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
