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
  Timer? _timer;
  Duration _tiempoRestanteEntrada = Duration.zero;
  Duration _tiempoRetrasoEntrada = Duration.zero;
  bool _puedeMarcarEntrada = false;
  Duration _tiempoRestanteSalida = Duration.zero;
  Duration _tiempoRetrasoSalida = Duration.zero;
  bool _puedeMarcarSalida = false;
  double _progreso = 0.0;
  bool _mostrarTemporizadorSalida = false;

  // COLORES iOS 17 COMPACTOS
  static const Color _iosBlue = Color(0xFF007AFF);
  static const Color _iosGreen = Color(0xFF34C759);
  static const Color _iosOrange = Color(0xFFFF9500);
  static const Color _iosRed = Color(0xFFFF3B30);
  static const Color _iosYellow = Color(0xFFFFCC00);
  static const Color _iosGray = Color(0xFF8E8E93);
  static const Color _iosLightGray = Color(0xFFF2F2F7);
  static const Color _iosSeparator = Color(0xFFC6C6C8);

  @override
  void initState() {
    super.initState();
    _calcularTiempos();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => _calcularTiempos());
  }

  @override
  void didUpdateWidget(covariant HorarioCardExtended oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.horario != widget.horario) _calcularTiempos();
  }

  void _calcularTiempos() {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    try {
      final horaInicioParts = widget.horario.horaInicio.split(':');
      final horaFinParts = widget.horario.horaFin.split(':');
      final inicio = DateTime(hoy.year, hoy.month, hoy.day,
          int.parse(horaInicioParts[0]), int.parse(horaInicioParts[1]));
      final fin = DateTime(hoy.year, hoy.month, hoy.day,
          int.parse(horaFinParts[0]), int.parse(horaFinParts[1]));

      double progreso = 0.0;
      final totalDuracion = fin.difference(inicio);
      if (!widget.horario.yaMarcoEntrada && totalDuracion.inSeconds > 0) {
        progreso =
            (ahora.difference(inicio).inSeconds / totalDuracion.inSeconds)
                .clamp(0.0, 1.0);
      } else if (widget.horario.yaMarcoEntrada &&
          !widget.horario.yaMarcoSalida) {
        progreso = (ahora.difference(fin).inSeconds /
                const Duration(minutes: 30).inSeconds)
            .clamp(0.0, 1.0);
      } else if (widget.horario.estaCompletado) {
        progreso = 1.0;
      }

      Duration tiempoRestanteEntrada = Duration.zero;
      Duration tiempoRetrasoEntrada = Duration.zero;
      if (ahora.isBefore(inicio))
        tiempoRestanteEntrada = inicio.difference(ahora);
      else if (ahora.isAfter(inicio) && !widget.horario.yaMarcoEntrada)
        tiempoRetrasoEntrada = ahora.difference(inicio);
      final entradaAntes = inicio.subtract(const Duration(minutes: 30));
      final entradaDespues = inicio.add(const Duration(minutes: 150));
      final puedeMarcarEntrada = !widget.horario.yaMarcoEntrada &&
          ahora.isAfter(entradaAntes) &&
          ahora.isBefore(entradaDespues);

      final mostrarTemporizadorSalida =
          widget.horario.yaMarcoEntrada && !widget.horario.yaMarcoSalida;
      Duration tiempoRestanteSalida = Duration.zero;
      Duration tiempoRetrasoSalida = Duration.zero;
      if (mostrarTemporizadorSalida) {
        if (ahora.isBefore(fin))
          tiempoRestanteSalida = fin.difference(ahora);
        else if (ahora.isAfter(fin))
          tiempoRetrasoSalida = ahora.difference(fin);
      }
      final salidaAntes = fin.subtract(const Duration(minutes: 30));
      final salidaDespues = fin.add(const Duration(minutes: 30));
      final puedeMarcarSalida = widget.horario.yaMarcoEntrada &&
          !widget.horario.yaMarcoSalida &&
          ahora.isAfter(salidaAntes) &&
          ahora.isBefore(salidaDespues);

      if (mounted) {
        setState(() {
          _progreso = progreso;
          _tiempoRestanteEntrada = tiempoRestanteEntrada;
          _tiempoRetrasoEntrada = tiempoRetrasoEntrada;
          _puedeMarcarEntrada = puedeMarcarEntrada;
          _tiempoRestanteSalida = tiempoRestanteSalida;
          _tiempoRetrasoSalida = tiempoRetrasoSalida;
          _puedeMarcarSalida = puedeMarcarSalida;
          _mostrarTemporizadorSalida = mostrarTemporizadorSalida;
        });
      }
    } catch (e) {
      debugPrint('Error calculando tiempos: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatearTiempo(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }

  Color _getColorEstadoEntrada() {
    if (_tiempoRetrasoEntrada.inMinutes > 0) {
      final minutos = _tiempoRetrasoEntrada.inMinutes;
      if (minutos < 5) return _iosOrange;
      if (minutos < 15) return Colors.orange.shade700;
      return _iosRed;
    }
    return _tiempoRestanteEntrada.inMinutes > 0 ? _iosBlue : _iosGreen;
  }

  IconData _getIconoEntrada() {
    if (_tiempoRetrasoEntrada.inMinutes > 0)
      return CupertinoIcons.exclamationmark_triangle_fill;
    if (_tiempoRestanteEntrada.inSeconds > 0) return CupertinoIcons.timer;
    return CupertinoIcons.checkmark_circle_fill;
  }

  String _getTextoEntrada() {
    if (_tiempoRetrasoEntrada.inMinutes > 0) {
      final minutos = _tiempoRetrasoEntrada.inMinutes;
      final segundos = _tiempoRetrasoEntrada.inSeconds.remainder(60);
      if (minutos > 60)
        return 'Retraso entrada: ${minutos ~/ 60}h ${minutos % 60}m';
      return 'Retraso entrada: ${minutos}m ${segundos}s';
    }
    if (_tiempoRestanteEntrada.inSeconds > 0)
      return 'Falta para entrada: ${_formatearTiempo(_tiempoRestanteEntrada)}';
    if (widget.horario.yaMarcoEntrada) return 'Entrada marcada';
    return 'Hora de entrada';
  }

  Color _getColorEstadoSalida() {
    if (_tiempoRetrasoSalida.inMinutes > 0)
      return _tiempoRetrasoSalida.inMinutes < 5 ? _iosOrange : _iosRed;
    return _tiempoRestanteSalida.inSeconds > 0 ? _iosRed : _iosGreen;
  }

  IconData _getIconoSalida() {
    if (_tiempoRetrasoSalida.inMinutes > 0)
      return CupertinoIcons.exclamationmark_triangle_fill;
    if (_tiempoRestanteSalida.inSeconds > 0) return CupertinoIcons.timer;
    return CupertinoIcons.checkmark_circle_fill;
  }

  String _getTextoSalida() {
    if (_tiempoRetrasoSalida.inMinutes > 0) {
      final minutos = _tiempoRetrasoSalida.inMinutes;
      final segundos = _tiempoRetrasoSalida.inSeconds.remainder(60);
      if (minutos > 60)
        return 'Retraso salida: ${minutos ~/ 60}h ${minutos % 60}m';
      return 'Retraso salida: ${minutos}m ${segundos}s';
    }
    if (_tiempoRestanteSalida.inSeconds > 0)
      return 'Falta para salida: ${_formatearTiempo(_tiempoRestanteSalida)}';
    if (widget.horario.yaMarcoSalida) return 'Salida marcada';
    return 'Hora de salida';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoCard(
      margin: const EdgeInsets.only(bottom: 6), // REDUCIDO de 10 a 6
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // HEADER COMPACTO
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 8), // REDUCIDO de 12,10
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: _getColorHeader(),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12)), // REDUCIDO de 14
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.horario.materia,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis), // 15 -> 14
                    const SizedBox(height: 1),
                    Text('Paralelo ${widget.horario.paralelo}',
                        style: const TextStyle(
                            fontSize: 10.5,
                            color: Colors.white70)), // 11 -> 10.5
                  ]),
            ),
            _buildBadgeEstado(),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(10), // REDUCIDO de 12
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // HORARIO Y UBICACION
            Row(children: [
              Icon(CupertinoIcons.clock, size: 12, color: _iosGray), // 13 -> 12
              const SizedBox(width: 3),
              Text('${widget.horario.horaInicio} - ${widget.horario.horaFin}',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500)), // 12 -> 11.5
              if (widget.horario.ubicacion != null) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Row(children: [
                    Icon(CupertinoIcons.location,
                        size: 11, color: _iosGray), // 12 -> 11
                    const SizedBox(width: 2),
                    Expanded(
                        child: Text(widget.horario.ubicacion!,
                            style: TextStyle(
                                fontSize: 10.5, color: Colors.black54),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)), // 11 -> 10.5
                  ]),
                ),
              ],
            ]),

            // BARRA DE PROGRESO
            if (!widget.horario.estaCompletado) ...[
              const SizedBox(height: 8), // 10 -> 8
              ClipRRect(
                borderRadius: BorderRadius.circular(2), // 3 -> 2
                child: LinearProgressIndicator(
                    value: _progreso,
                    minHeight: 3,
                    backgroundColor: _iosLightGray,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        _progreso > 0.8 ? _iosGreen : _iosBlue)), // 4 -> 3
              ),
            ],

            // TEMPORIZADOR ENTRADA
            if (!widget.horario.yaMarcoEntrada) ...[
              const SizedBox(height: 6), // 8 -> 6
              _buildEstadoContainer(
                  color: _getColorEstadoEntrada(),
                  icon: _getIconoEntrada(),
                  texto: _getTextoEntrada(),
                  mostrarTarde: _tiempoRetrasoEntrada.inMinutes > 0),
            ],

            // TEMPORIZADOR SALIDA
            if (_mostrarTemporizadorSalida) ...[
              const SizedBox(height: 6),
              _buildEstadoContainer(
                  color: _getColorEstadoSalida(),
                  icon: _getIconoSalida(),
                  texto: _getTextoSalida(),
                  mostrarTarde: _tiempoRetrasoSalida.inMinutes > 0),
            ],

            const SizedBox(height: 10), // 12 -> 10

            // BOTONES
            if (!widget.horario.estaCompletado)
              Row(children: [
                if (!widget.horario.yaMarcoEntrada)
                  Expanded(
                      child: _buildBotonIOS(
                          texto: 'Marcar Entrada',
                          icon: CupertinoIcons.arrow_right_to_line_alt,
                          color: _iosBlue,
                          disponible: _puedeMarcarEntrada,
                          onPressed: widget.onMarcarEntrada)),
                if (widget.horario.yaMarcoEntrada &&
                    !widget.horario.yaMarcoSalida)
                  Expanded(
                      child: _buildBotonIOS(
                          texto: 'Marcar Salida',
                          icon: CupertinoIcons.arrow_left_to_line_alt,
                          color: _iosRed,
                          disponible: _puedeMarcarSalida,
                          onPressed: () => _mostrarDialogoSalida(context))),
              ]),

            // ESTADO COMPLETADO
            if (widget.horario.estaCompletado) ...[
              const SizedBox(height: 8), // 10 -> 8
              Container(
                padding: const EdgeInsets.all(8), // 10 -> 8
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_iosGreen, _iosGreen.withOpacity(0.8)]),
                    borderRadius: BorderRadius.circular(7)), // 8 -> 7
                child: Row(children: [
                  const Icon(CupertinoIcons.checkmark_circle_fill,
                      color: Colors.white, size: 14), // 16 -> 14
                  const SizedBox(width: 6), // 8 -> 6
                  const Text('Asistencia completada',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)), // 12 -> 11.5
                  const Spacer(),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(CupertinoIcons.checkmark,
                          color: Colors.white, size: 12)), // 14 -> 12
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _buildBadgeEstado() {
    String texto = 'Pendiente';
    if (widget.horario.estaCompletado)
      texto = 'Completado';
    else if (widget.horario.yaMarcoEntrada) texto = 'En curso';
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2), // 8,3 -> 7,2
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12)), // 14 -> 12
      child: Text(texto,
          style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.2)), // 9 -> 8.5
    );
  }

  Widget _buildEstadoContainer(
      {required Color color,
      required IconData icon,
      required String texto,
      required bool mostrarTarde}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // 10,7 -> 8,6
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(7),
          border:
              Border.all(color: color.withOpacity(0.2), width: 0.5)), // 8 -> 7
      child: Row(children: [
        Icon(icon, color: color, size: 13), // 14 -> 13
        const SizedBox(width: 5), // 6 -> 5
        Expanded(
            child: Text(texto,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: color))), // 12 -> 11.5
        if (mostrarTarde)
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4)),
              child: Text('Tarde',
                  style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w600,
                      color: color))), // 8 -> 7.5
      ]),
    );
  }

  List<Color> _getColorHeader() {
    if (widget.horario.estaCompletado)
      return [_iosGreen, _iosGreen.withOpacity(0.8)];
    if (widget.horario.yaMarcoEntrada) return [_iosYellow, _iosOrange];
    return [_iosBlue, _iosBlue.withOpacity(0.8)];
  }

  Widget _buildBotonIOS(
      {required String texto,
      required IconData icon,
      required Color color,
      required bool disponible,
      required VoidCallback onPressed}) {
    return CupertinoButton(
      onPressed: disponible ? onPressed : null,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(7), // 8 -> 7
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 32, // 36 -> 32
        decoration: BoxDecoration(
            color: disponible ? color : _iosLightGray,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color: disponible ? color : _iosSeparator, width: 0.5)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 14,
              color: disponible ? Colors.white : _iosGray), // 15 -> 14
          const SizedBox(width: 4), // 5 -> 4
          Text(texto,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: disponible ? Colors.white : _iosGray)), // 12 -> 11.5
        ]),
      ),
    );
  }

  void _mostrarDialogoSalida(BuildContext context) {
    final ahora = DateTime.now();
    final horaFinParts = widget.horario.horaFin.split(':');
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final fin = DateTime(hoy.year, hoy.month, hoy.day,
        int.parse(horaFinParts[0]), int.parse(horaFinParts[1]));
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
      icono = CupertinoIcons.exclamationmark_triangle_fill;
    } else if (minutosDiferencia <= 15) {
      titulo = 'Salida en Horario';
      mensaje = 'Está saliendo dentro del horario establecido.';
      color = _iosGreen;
      icono = CupertinoIcons.checkmark_circle_fill;
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
        title: Row(children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 6),
          Text(titulo, style: const TextStyle(fontSize: 16))
        ]), // 22 -> 20
        content: Column(children: [
          const SizedBox(height: 5), // 6 -> 5
          Text(mensaje, style: const TextStyle(fontSize: 13)), // NUEVO
          const SizedBox(height: 8), // 10 -> 8
          Container(
            padding: const EdgeInsets.all(8), // 10 -> 8
            decoration: BoxDecoration(
                color: _iosLightGray,
                borderRadius: BorderRadius.circular(7)), // 8 -> 7
            child: Column(children: [
              _buildInfoRowIOS('Materia', widget.horario.materia),
              _buildInfoRowIOS('Paralelo', widget.horario.paralelo),
              _buildInfoRowIOS('Hora salida', widget.horario.horaFin),
              _buildInfoRowIOS(
                  'Hora actual', DateFormat('HH:mm').format(ahora)),
              if (minutosDiferencia.abs() > 0)
                _buildInfoRowIOS('Diferencia',
                    '${minutosDiferencia.abs()} min ${minutosDiferencia > 0 ? 'después' : 'antes'}'),
            ]),
          ),
        ]),
        actions: [
          CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(context);
                widget.onMarcarSalida();
              },
              isDestructiveAction: minutosDiferencia.abs() > 15,
              child: Text('Confirmar',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildInfoRowIOS(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1), // 2 -> 1
      child: Row(children: [
        SizedBox(
            width: 75,
            child: Text(label,
                style: TextStyle(
                    fontSize: 10.5, color: _iosGray))), // 80,11 -> 75,10.5
        Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.black))), // 11 -> 10.5
      ]),
    );
  }
}

class CupertinoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  const CupertinoCard(
      {super.key, required this.child, this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // 14 -> 12
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 1)), // blur 10->8
          BoxShadow(
              color: Colors.black.withOpacity(0.01),
              blurRadius: 3,
              offset: const Offset(0, 1)), // blur 4->3
        ],
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(12), child: child), // 14 -> 12
    );
  }
}
