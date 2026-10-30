part of '../../screens/guia_practica_screen.dart';

// ============================================
// GUIA DE USO - TUTORIAL Y DEDO INDICADOR
// ============================================
// Recuadros que resaltan cada parte de la tarjeta (se leen en voz alta y
// avanzan solos) y el dedo animado que senala el boton que hay que tocar.

mixin _GuiaTutorial on State<GuiaPracticaScreen> {
  // Datos de la pantalla que usa el tutorial
  EtapaGuia get _etapa;
  bool get _modoSalida;
  Horario? get _horarioDemo;
  Future<bool> _hablar(String texto);
  void _detenerVoz();

  // Texto que se lee para cada recuadro del tutorial (por id)
  final Map<String, String> _vozTargets = {};

  // Tutorial en pantalla (para avanzarlo solo al terminar la voz)
  TutorialCoachMark? _tutorial;
  String? _targetActual;

  // Dedo indicador: posicion de la punta y zona de la tarjeta.
  // Con ValueNotifier, al moverse el dedo solo se redibuja su zona y no
  // toda la pantalla
  final ValueNotifier<Offset?> _posMano = ValueNotifier(null);
  // Cuadros seguidos que se espero a que aparezca el boton senalado
  int _esperasMano = 0;
  final GlobalKey _keyStackTarjeta = GlobalKey();

  // Dedo reutilizable: que boton senala, dentro de que zona (Stack) se
  // dibuja y que texto muestra
  GlobalKey? _manoObjetivo;
  GlobalKey? _manoStack;
  String _manoTexto = '';
  final GlobalKey _keyStackSalida = GlobalKey();

  // Claves para resaltar las partes de la tarjeta en el tutorial
  final GlobalKey _keyEncabezado = GlobalKey();
  final GlobalKey _keyUbicacion = GlobalKey();
  final GlobalKey _keyEstado = GlobalKey();
  final GlobalKey _keyBotones = GlobalKey();
  final GlobalKey _keySalida = GlobalKey();

  // Dedo sobre "Confirmar" del dialogo de salida. El dialogo esta
  // encima de la pantalla, asi que el dedo se dibuja en el Overlay
  final GlobalKey _keyConfirmarSalida = GlobalKey();
  OverlayEntry? _manoConfirmar;
  Timer? _timerConfirmar;

  // ─────────────────────────────────────────────────────────────
  //  Tutorial sobre la tarjeta
  // ─────────────────────────────────────────────────────────────
  // Solo resalta partes que ya estan dibujadas en pantalla
  void _mostrarTutorialTarjeta() {
    if (_horarioDemo == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Esperar a que la tarjeta termine de dibujarse
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted || _etapa != EtapaGuia.tarjeta) return;

      final targets = <TargetFocus>[
        // Primero un enfoque en toda la tarjeta
        _crearTarget(
          'tarjeta',
          _keyStackTarjeta,
          ContentAlign.bottom,
          'Una vez ingresado al sistema',
          'Se podrá observar una tarjeta por cada clase del día. Desde ella marcarás tu entrada y salida.',
        ),
        _crearTarget(
          'encabezado',
          _keyEncabezado,
          ContentAlign.bottom,
          'El encabezado de la tarjeta',
          'Muestra la materia, paralelo y el horario. El color azul significa marcado pendiente.',
        ),
        _crearTarget(
          'ubicacion',
          _keyUbicacion,
          ContentAlign.bottom,
          'Aula de ejemplo',
          'Indica el nombre del aula y la hora de inicio y fin de la clase. '
              'Para ver en el mapa la zona donde debes marcar, toca el nombre del aula.',
        ),
        _crearTarget(
          'estado',
          _keyEstado,
          ContentAlign.bottom,
          'Temporizador de entrada',
          'Indica cuánto falta para que comience la clase. La entrada se marca desde 30 min antes.',
        ),
        _crearTarget(
          'botones',
          _keyBotones,
          ContentAlign.top,
          'Boton "Marcar Entrada"',
          'Tócalo al llegar al aula para registrar su entrada.',
        ),
      ];
      _mostrarTargets(targets);
    });
  }

  // Tutorial sobre la tarjeta de salida (etapa 4)
  void _mostrarTutorialSalida() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted || _etapa != EtapaGuia.salida) return;

      _mostrarTargets([
        _crearTarget(
          'encabezado_salida',
          _keyEncabezado,
          ContentAlign.bottom,
          'Una vez que la entrada fue marcada',
          'La tarjeta cambia de color a un tono naranja, lo cual significa actividades en curso.',
        ),
        _crearTarget(
          'temporizador_salida',
          _keySalida,
          ContentAlign.bottom,
          'Temporizador de salida',
          'Indica cuánto falta para terminar la clase.',
        ),
        _crearTarget(
          'boton_salida',
          _keyBotones,
          ContentAlign.top,
          'Boton "Marcar Salida"',
          'Se habilita 30 min antes de que finalice las actividades.',
        ),
      ]);
    });
  }

  // Muestra el tutorial solo con las partes que ya estan dibujadas
  void _mostrarTargets(List<TargetFocus> targets) {
    final visibles =
        targets.where((t) => t.keyTarget?.currentContext != null).toList();
    if (visibles.isEmpty) return;

    _tutorial = TutorialCoachMark(
      targets: visibles,
      colorShadow: Colors.black87,
      opacityShadow: 0.8,
      paddingFocus: 8,
      textSkip: 'SALTAR',
      // Lee cada recuadro al mostrarse y avanza solo al terminar.
      // No se espera aqui: el tutorial no muestra el recuadro hasta que
      // beforeFocus termina.
      beforeFocus: (target) {
        _targetActual = target.identify;
        _leerYAvanzar(target.identify);
      },
      onFinish: _alTerminarTutorial,
      onSkip: () {
        _alTerminarTutorial();
        return true;
      },
    )..show(context: context);
  }

  Future<void> _leerYAvanzar(String id) async {
    final termino = await _hablar(_vozTargets[id] ?? '');
    if (!termino) return; // silenciado o interrumpido: avanza al tocar
    await Future.delayed(const Duration(milliseconds: 600));
    // Seguir solo si nadie avanzo el tutorial mientras tanto
    if (mounted && _tutorial != null && _targetActual == id) {
      _tutorial!.next();
    }
  }

  void _alTerminarTutorial() {
    _tutorial = null;
    _targetActual = null;
    _detenerVoz();
    if (!mounted) return;
    if (_etapa == EtapaGuia.tarjeta) _mostrarManoEntrada();
    if (_etapa == EtapaGuia.salida) {
      _mostrarManoEn(
        objetivo: _keyBotones,
        stack: _keyStackSalida,
        texto: 'Toca Marcar Salida',
        voz: 'Ahora toca el botón rojo, Marcar Salida.',
      );
      _vigilarDialogoSalida();
    }
  }

  TargetFocus _crearTarget(
    String id,
    GlobalKey key,
    ContentAlign alineacion,
    String titulo,
    String descripcion,
  ) {
    _vozTargets[id] = '$titulo. $descripcion';
    return TargetFocus(
      identify: id,
      keyTarget: key,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: alineacion,
          child: _TextoTutorial(titulo, descripcion),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Dedo sobre "Confirmar" del dialogo de salida
  // ─────────────────────────────────────────────────────────────
  // Mientras el dialogo de salida este abierto, dibuja un dedo
  // sobre "Confirmar" (sin voz). Se revisa seguido porque el dialogo se
  // abre y se cierra desde la tarjeta, y entra con una animacion.
  void _vigilarDialogoSalida() {
    _timerConfirmar?.cancel();
    _timerConfirmar = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (!mounted) return;
      final abierto = _keyConfirmarSalida.currentContext != null;
      if (abierto && _manoConfirmar == null) {
        _detenerVoz();
        // Ya se toco "Marcar Salida": quitar ese dedo del fondo
        setState(_ocultarManoPantalla);
        _manoConfirmar = OverlayEntry(builder: _buildManoConfirmar);
        Overlay.of(context, rootOverlay: true).insert(_manoConfirmar!);
      } else if (!abierto && _manoConfirmar != null) {
        _quitarManoConfirmar();
        if (_modoSalida || _etapa != EtapaGuia.salida) {
          // Se confirmo la salida: ya no hace falta ningun dedo
          _timerConfirmar?.cancel();
          _timerConfirmar = null;
        } else {
          // Se cancelo el dialogo: volver a senalar "Marcar Salida" (sin voz)
          _mostrarManoEn(
            objetivo: _keyBotones,
            stack: _keyStackSalida,
            texto: 'Toca Marcar Salida',
          );
        }
      } else {
        // Seguir la posicion del boton mientras el dialogo se anima
        _manoConfirmar?.markNeedsBuild();
      }
    });
  }

  Widget _buildManoConfirmar(BuildContext context) {
    final box =
        _keyConfirmarSalida.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return const SizedBox.shrink();
    final centro = box.localToGlobal(box.size.center(Offset.zero));
    return Positioned(
      left: centro.dx - 60,
      top: centro.dy - 8,
      child: const IgnorePointer(
        // Fuera del Scaffold: Material para que el texto tenga su estilo
        child: Material(
          type: MaterialType.transparency,
          child: _ManoIndicadora(texto: 'Toca Confirmar'),
        ),
      ),
    );
  }

  void _quitarManoConfirmar() {
    _manoConfirmar?.remove();
    _manoConfirmar = null;
  }

  void _detenerManoConfirmar() {
    _timerConfirmar?.cancel();
    _timerConfirmar = null;
    _quitarManoConfirmar();
  }

  // ─────────────────────────────────────────────────────────────
  //  Dedo indicador
  // ─────────────────────────────────────────────────────────────
  // _mostrarManoEn() sirve para cualquier boton de la tarjeta de entrada
  // o de salida. El dedo se dibuja dentro de la zona creada con _conMano().

  // Tarjeta de entrada: senala "Marcar Entrada"
  void _mostrarManoEntrada() {
    _mostrarManoEn(
      objetivo: _keyBotones,
      stack: _keyStackTarjeta,
      texto: 'Toca Marcar Entrada',
      voz: 'Ahora toca el botón azul, Marcar Entrada.',
    );
  }

  void _mostrarManoEn({
    required GlobalKey objetivo,
    required GlobalKey stack,
    required String texto,
    String? voz,
  }) {
    setState(() {
      _manoObjetivo = objetivo;
      _manoStack = stack;
      _manoTexto = texto;
    });
    _posMano.value = null;
    _esperasMano = 0;
    if (voz != null) _hablar(voz);

    // Despues se reubica solo cuando la tarjeta cambia de tamano
    // (mapa, temporizador), ver _conMano()
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _actualizarPosicionMano());
  }

  void _ocultarMano() {
    _detenerManoConfirmar();
    _ocultarManoPantalla();
  }

  // Solo el dedo dibujado en la pantalla (no el del dialogo de salida)
  void _ocultarManoPantalla() {
    _manoObjetivo = null;
    _manoStack = null;
    _posMano.value = null;
  }

  // Posicion de la punta del dedo, relativa a su zona (Stack)
  void _actualizarPosicionMano() {
    final objetivo = _manoObjetivo;
    final stack = _manoStack;
    if (!mounted || objetivo == null || stack == null) return;
    final rect = _rectRelativo(objetivo, stack);
    if (rect == null) {
      // El boton aun no se dibujo: probar en el siguiente cuadro (max ~1 s)
      if (_esperasMano++ < 60) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _actualizarPosicionMano());
      }
      return;
    }
    _esperasMano = 0;
    // Solo avisa (y redibuja la zona) si la posicion cambio
    _posMano.value = rect.center;
  }

  Rect? _rectRelativo(GlobalKey key, GlobalKey stackKey) {
    final stack = stackKey.currentContext?.findRenderObject() as RenderBox?;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || box == null || !box.attached || !stack.attached) {
      return null;
    }
    final origen = box.localToGlobal(Offset.zero, ancestor: stack);
    return origen & box.size;
  }

  // Envuelve un contenido en una zona donde se puede dibujar el dedo.
  // Deja espacio abajo para la etiqueta cuando el dedo esta visible.
  // Al moverse el dedo solo se reconstruye esta zona; el contenido (child)
  // se reutiliza sin volver a construirse.
  Widget _conMano(GlobalKey stackKey, Widget child) {
    // Si la tarjeta cambia de tamano (aparece el mapa o el temporizador),
    // reubicar el dedo despues de dibujarla
    final contenido = NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        if (_manoStack == stackKey) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _actualizarPosicionMano());
        }
        return true;
      },
      child: SizeChangedLayoutNotifier(child: child),
    );

    return ValueListenableBuilder<Offset?>(
      valueListenable: _posMano,
      child: contenido,
      builder: (context, pos, contenido) {
        final visible = _manoStack == stackKey && pos != null;
        return Padding(
          padding: EdgeInsets.only(bottom: visible ? 90 : 0),
          child: Stack(
            key: stackKey,
            clipBehavior: Clip.none,
            children: [
              contenido!,
              if (visible)
                Positioned(
                  // La punta del dedo (arriba al centro del widget) toca el
                  // objetivo
                  left: pos.dx - 60,
                  top: pos.dy - 8,
                  child:
                      IgnorePointer(child: _ManoIndicadora(texto: _manoTexto)),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Texto blanco de cada recuadro del tutorial
class _TextoTutorial extends StatelessWidget {
  final String titulo;
  final String descripcion;

  const _TextoTutorial(this.titulo, this.descripcion);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _darkColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            descripcion,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Dedo animado que indica donde tocar
// ─────────────────────────────────────────────────────────────
// La punta del dedo queda arriba al centro del widget (ancho 120)
class _ManoIndicadora extends StatefulWidget {
  final String texto;

  const _ManoIndicadora({required this.texto});

  @override
  State<_ManoIndicadora> createState() => _ManoIndicadoraState();
}

// Mano blanca con sombra que "presiona" y una onda de toque en la punta
// del dedo. Cada ciclo: la mano baja (toque), sale la onda y la mano sube.
class _ManoIndicadoraState extends State<_ManoIndicadora>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const double _ancho = 120;
  // Punta del dedo dentro del widget (arriba al centro)
  static const double _puntaY = 8;
  static const double _tamanoMano = 46;
  static const Color _azul = Color(0xFF4A6CF7);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
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
      width: _ancho,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _ancho,
            height: _tamanoMano + 10,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;

                // La mano baja durante el primer 20% del ciclo y vuelve
                final presion = t < 0.2
                    ? Curves.easeOut.transform(t / 0.2)
                    : t < 0.45
                        ? 1 - Curves.easeIn.transform((t - 0.2) / 0.25)
                        : 0.0;

                // La onda sale cuando la mano toca y se desvanece
                final onda = t < 0.15 ? 0.0 : ((t - 0.15) / 0.85);
                final tamanoOnda = 12 + 42 * Curves.easeOut.transform(onda);
                final opacidadOnda = (1 - onda) * 0.55;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Onda de toque centrada en la punta del dedo
                    Positioned(
                      left: _ancho / 2 - tamanoOnda / 2,
                      top: _puntaY - tamanoOnda / 2,
                      child: Container(
                        width: tamanoOnda,
                        height: tamanoOnda,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _azul.withValues(alpha: opacidadOnda * 0.5),
                          border: Border.all(
                            color: _azul.withValues(alpha: opacidadOnda),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Mano: el indice de pan_tool_alt esta un poco a la
                    // izquierda del centro del icono
                    Positioned(
                      left: _ancho / 2 - _tamanoMano * 0.42,
                      top: _puntaY - _tamanoMano * 0.06 + presion * 4,
                      child: Transform.scale(
                        scale: 1 - presion * 0.08,
                        child: const Icon(
                          Icons.pan_tool_alt_rounded,
                          size: _tamanoMano,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Color(0x66000000),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 2),
          // Etiqueta tipo "pildora"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _azul,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _azul.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              widget.texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
