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
  Duration _tiempoRestante = Duration.zero;
  Duration _tiempoRetraso = Duration.zero;
  bool _puedeMarcarSalida = false;
  bool _mostrarAlertaSalida = false;

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

    setState(() {
      // Tiempo para entrada
      if (ahora.isBefore(inicio)) {
        _tiempoRestante = inicio.difference(ahora);
        _tiempoRetraso = Duration.zero;
      } else if (ahora.isAfter(inicio) && !widget.horario.yaMarcoEntrada) {
        _tiempoRestante = Duration.zero;
        _tiempoRetraso = ahora.difference(inicio);
      } else {
        _tiempoRestante = Duration.zero;
        _tiempoRetraso = Duration.zero;
      }

      // Rango para salida: 30 minutos antes y 30 minutos después
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

  String _getEstadoTiempo() {
    if (_tiempoRetraso.inMinutes > 0) {
      final minutos = _tiempoRetraso.inMinutes;
      final segundos = _tiempoRetraso.inSeconds.remainder(60);
      return 'Retraso: $minutos min $segundos s';
    } else if (_tiempoRestante.inMinutes > 0 || _tiempoRestante.inSeconds > 0) {
      return 'Falta: ${_formatearTiempo(_tiempoRestante)}';
    }
    return 'Hora de entrada';
  }

  Color _getColorEstado() {
    if (_tiempoRetraso.inMinutes > 0) {
      final minutos = _tiempoRetraso.inMinutes;
      if (minutos < 5) return Colors.orange;
      if (minutos < 15) return Colors.deepOrange;
      return Colors.red;
    }
    return const Color(0xFF5B67CA);
  }

  String _getSubtituloEstado() {
    if (_tiempoRetraso.inMinutes > 0) {
      return 'No ha marcado entrada';
    } else if (_tiempoRestante.inMinutes > 0 || _tiempoRestante.inSeconds > 0) {
      return 'Tiempo para marcar entrada';
    }
    return 'Puede marcar entrada ahora';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.horario.materia,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3436),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Paralelo: ${widget.horario.paralelo}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF636E72),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.horario.estaCompletado
                        ? const Color(0xFF00B894).withOpacity(0.1)
                        : widget.horario.yaMarcoEntrada
                            ? Colors.orange.withOpacity(0.1)
                            : const Color(0xFF5B67CA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.horario.estaCompletado
                        ? 'Completado'
                        : widget.horario.yaMarcoEntrada
                            ? 'En curso'
                            : 'Pendiente',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.horario.estaCompletado
                          ? const Color(0xFF00B894)
                          : widget.horario.yaMarcoEntrada
                              ? Colors.orange
                              : const Color(0xFF5B67CA),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Horario y ubicación
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: Color(0xFF636E72),
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.horario.horaInicio} - ${widget.horario.horaFin}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF636E72),
                  ),
                ),
                if (widget.horario.ubicacion != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: Color(0xFF636E72),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.horario.ubicacion!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF636E72),
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

            const SizedBox(height: 12),

            // Temporizador de entrada (solo si no ha marcado entrada)
            if (!widget.horario.yaMarcoEntrada) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_rounded,
                      color: _getColorEstado(),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getEstadoTiempo(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: _getColorEstado(),
                            ),
                          ),
                          Text(
                            _getSubtituloEstado(),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getColorEstado().withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_tiempoRetraso.inMinutes > 0)
                      Icon(
                        Icons.warning_amber_rounded,
                        color: _getColorEstado(),
                        size: 24,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Botones
            Row(
              children: [
                // Botón Entrada
                if (!widget.horario.yaMarcoEntrada)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onMarcarEntrada,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B67CA),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(0, 40),
                      ),
                      child: const Text('Marcar Entrada'),
                    ),
                  ),

                // Botón Salida
                if (widget.horario.yaMarcoEntrada &&
                    !widget.horario.yaMarcoSalida)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _puedeMarcarSalida
                          ? () => _mostrarDialogoSalida(context)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _puedeMarcarSalida
                            ? const Color(0xFFE17055)
                            : Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(0, 40),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Marcar Salida'),
                          if (!_puedeMarcarSalida)
                            const Text(
                              '30 min antes/despues',
                              style: TextStyle(
                                fontSize: 9,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            if (widget.horario.estaCompletado)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B894).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: const Color(0xFF00B894),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Asistencia completada',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF00B894),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
    Color color = const Color(0xFF5B67CA);

    if (minutosDiferencia < 0) {
      final minutosAntes = minutosDiferencia.abs();
      titulo = 'Salida anticipada';
      mensaje =
          'Está saliendo $minutosAntes minutos antes de la hora programada.';
      color = minutosAntes > 15 ? Colors.red : Colors.orange;
    } else if (minutosDiferencia <= 15) {
      titulo = 'Salida en horario';
      mensaje = 'Está saliendo dentro del horario establecido.';
      color = const Color(0xFF00B894);
    } else {
      titulo = 'Salida tardía';
      mensaje =
          'Está saliendo $minutosDiferencia minutos después de la hora programada.';
      color = Colors.orange;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.exit_to_app_rounded,
              color: color,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              titulo,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mensaje),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
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
                      '${minutosDiferencia.abs()} min ${minutosDiferencia > 0 ? 'despues' : 'antes'}',
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context, true);
              widget.onMarcarSalida();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF636E72),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2D3436),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
