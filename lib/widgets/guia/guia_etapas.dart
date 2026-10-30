part of '../../screens/guia_practica_screen.dart';

// ============================================
// GUIA DE USO - PIEZAS VISUALES DE CADA ETAPA
// ============================================
// Widgets que solo muestran datos: reciben lo que necesitan y avisan con
// callbacks. El flujo (que etapa sigue, verificaciones, camara) esta en
// guia_practica_screen.dart.

const Color _primaryColor = Color(0xFF4A6CF7);
const Color _warningColor = Color(0xFFF59E0B);
const Color _darkColor = Color(0xFF1A2B4A);
const Color _successColor = Color(0xFF10B981);
const Color _dangerColor = Color(0xFFEF4444);

// ─────────────────────────────────────────────────────────────
//  Indicador "Paso X de N"
// ─────────────────────────────────────────────────────────────
class _ProgresoGuia extends StatelessWidget {
  final int numeroPaso;
  final int totalPasos;

  const _ProgresoGuia({required this.numeroPaso, required this.totalPasos});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paso $numeroPaso de $totalPasos',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: numeroPaso / totalPasos,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(_primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

// Tarjeta con icono, titulo y descripcion (etapa 1)
class _TextoEtapa extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;

  const _TextoEtapa(this.icono, this.titulo, this.descripcion);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icono, size: 48, color: _primaryColor),
            const SizedBox(height: 12),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              descripcion,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Etapa 2: aviso cuando no hay ubicacion para el mapa
// ─────────────────────────────────────────────────────────────
class _AvisoSinUbicacion extends StatelessWidget {
  final bool buscando;
  final VoidCallback onReintentar;

  const _AvisoSinUbicacion({
    required this.buscando,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _warningColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_off_rounded, color: _warningColor, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No se pudo obtener tu ubicación',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _darkColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Activa el GPS y el permiso de ubicación para ver el mapa con la '
            'zona de la clase. Sin GPS no podrás marcar en la app real.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: buscando ? null : onReintentar,
              icon: buscando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: Text(
                buscando ? 'Buscando...' : 'Reintentar ubicación',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Etapa 3: fila de una verificacion (huella, permisos o GPS)
// ─────────────────────────────────────────────────────────────
class _FilaVerificacion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final EstadoVerificacion estado;
  final String detalle;

  const _FilaVerificacion(this.icono, this.titulo, this.estado, this.detalle);

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Widget indicador;
    switch (estado) {
      case EstadoVerificacion.pendiente:
        color = Colors.grey;
        indicador = const Icon(Icons.radio_button_unchecked_rounded,
            color: Colors.grey, size: 22);
      case EstadoVerificacion.enCurso:
        color = _primaryColor;
        indicador = const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        );
      case EstadoVerificacion.ok:
        color = _successColor;
        indicador = const Icon(Icons.check_circle_rounded,
            color: _successColor, size: 22);
      case EstadoVerificacion.fallo:
        color = _dangerColor;
        indicador =
            const Icon(Icons.cancel_rounded, color: _dangerColor, size: 22);
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _darkColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detalle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            indicador,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Etapa 4: linea de tiempo de la regla de los 30 minutos
// ─────────────────────────────────────────────────────────────
class _ReglaSalida extends StatelessWidget {
  const _ReglaSalida();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule_rounded, color: _primaryColor, size: 18),
              SizedBox(width: 6),
              Text(
                '¿Cuándo puedo marcar la salida?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Tramo('Antes', Colors.grey.shade400, 'Deshabilitado'),
              const _Tramo('30 min antes → 30 min después del fin',
                  _successColor, 'Habilitado',
                  flex: 2),
              _Tramo('Después', Colors.grey.shade400, 'Deshabilitado'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Si sales antes o después, el aviso te muestra los minutos.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _Tramo extends StatelessWidget {
  final String texto;
  final Color color;
  final String estado;
  final int flex;

  const _Tramo(this.texto, this.color, this.estado, {this.flex = 1});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              estado,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: color == _successColor
                    ? _successColor
                    : Colors.grey.shade600,
              ),
            ),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Etapa 5: errores comunes
// ─────────────────────────────────────────────────────────────
// Los titulos son los mismos mensajes que muestra el marcado real
// (home_screen.dart)
class _EtapaConsejos extends StatelessWidget {
  const _EtapaConsejos();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Avisos comunes. Toca uno para ver qué hacer.',
          style: TextStyle(fontSize: 14, color: _darkColor, height: 1.4),
        ),
        const SizedBox(height: 12),
        const _Consejo(
          Icons.visibility_off_rounded,
          _warningColor,
          'Gafas detectadas',
          'Los lentes impiden reconocer tu rostro.',
          'Quítatelos y toca "Reintentar".',
        ),
        const _Consejo(
          Icons.warning_amber_rounded,
          _dangerColor,
          'Suplantación detectada',
          'La foto parece de una pantalla, impresa o de otra persona. Se '
              'informa al supervisor.',
          'Ponte tú frente a la cámara.',
        ),
        const _Consejo(
          Icons.pan_tool_rounded,
          _warningColor,
          'Gesto incorrecto',
          'El gesto no coincide con el pedido.',
          'Lee la instrucción del marco y haz el gesto claro.',
        ),
        const _Consejo(
          Icons.wrong_location_rounded,
          _dangerColor,
          'Fuera de la zona',
          'No estás dentro de la zona del aula.',
          'Marca desde el aula. Toca el aula en la tarjeta para ver el mapa.',
        ),
        const _Consejo(
          Icons.location_off_rounded,
          _dangerColor,
          'El GPS está desactivado',
          'Sin GPS no se puede marcar.',
          'Activa la ubicación; la app te lleva a los ajustes.',
        ),
        const SizedBox(height: 4),
        Text(
          'En cualquier error, "Reintentar" repite el marcado.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

// Aviso desplegable: al tocarlo muestra por que aparece y que hacer
class _Consejo extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String causa;
  final String solucion;

  const _Consejo(
      this.icono, this.color, this.titulo, this.causa, this.solucion);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icono, color: color),
        title: Text(
          titulo,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _darkColor,
          ),
        ),
        shape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _linea('Por qué aparece', causa),
          const SizedBox(height: 8),
          _linea('Qué hacer', solucion),
        ],
      ),
    );
  }

  Widget _linea(String etiqueta, String texto) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$etiqueta: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: texto),
        ],
      ),
      style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Etapa 6: resumen final
// ─────────────────────────────────────────────────────────────
class _EtapaFin extends StatelessWidget {
  const _EtapaFin();

  static const _pasos = [
    'En el aula, toca "Marcar Entrada".',
    'Huella y GPS encendido.',
    'Las 3 fotos: rostro, gesto y aula.',
    'Al terminar, "Marcar Salida": se repite lo mismo.',
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 56, color: _successColor),
            const SizedBox(height: 12),
            const Text(
              '¡Listo! Ya conoces el marcado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkColor,
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _pasos.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: _primaryColor,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _pasos[i],
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.grey.shade800,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'Puedes volver a ver esta guía desde el botón de ayuda del '
              'Home o en Perfil > Opciones > Guía de uso.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Tarjeta flotante (contenido del dialogo de exito y de proceso)
// ─────────────────────────────────────────────────────────────
// Icono, titulo, texto y "Continuar". Sin boton (conBoton: false) la
// cierra quien la abrio.
class _TarjetaFlotante extends StatelessWidget {
  final Widget cabecera;
  final String titulo;
  final String texto;
  final Color color;
  final bool textoSecundario;
  final bool conBoton;

  const _TarjetaFlotante({
    required this.cabecera,
    required this.titulo,
    required this.texto,
    required this.color,
    required this.textoSecundario,
    required this.conBoton,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          cabecera,
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _darkColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: textoSecundario
                ? TextStyle(fontSize: 12.5, color: Colors.grey.shade600)
                : const TextStyle(fontSize: 14, color: _darkColor, height: 1.4),
          ),
        ],
      ),
      actions: [
        if (conBoton)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Continuar'),
            ),
          ),
      ],
    );
  }
}
