import 'package:flutter/material.dart';

// ============================================
// GUIA VISUAL DEL ROSTRO EN LA CAMARA
// ============================================
// Silueta transparente que se dibuja dentro del recuadro de captura para
// mostrar con movimiento lo que se pide, ademas de la voz y el texto:
// - Foto frontal: la silueta queda quieta y "respira" para que el usuario
//   ubique su rostro dentro de ella.
// - Foto de gesto: los hombros quedan fijos y solo la cabeza gira hacia el
//   lado pedido, se mantiene un momento y vuelve al frente, en ciclo, con
//   una flecha que indica la direccion.
//
// La silueta son dos PNG del mismo tamano que se superponen: la cabeza
// (la parte que se anima) y el cuello con los hombros (fijo). Si se cambian
// las imagenes hay que actualizar [proporcion] y [centroCabeza].

class GuiaRostroAnimada extends StatefulWidget {
  // Gesto pedido: 'arriba', 'abajo', 'izquierda', 'derecha' o null (frontal)
  final String? gesto;
  final double ancho;
  final Color color;

  // La camara frontal se ve como espejo: si el usuario gira a SU izquierda,
  // en pantalla su rostro se va hacia la izquierda. Con la camara trasera
  // es al reves, por eso se invierte el sentido horizontal.
  final bool espejo;

  const GuiaRostroAnimada({
    super.key,
    required this.gesto,
    required this.ancho,
    required this.color,
    this.espejo = true,
  });

  static const String imagenCabeza = 'assets/guia/rostro_cabeza.png';
  static const String imagenCuerpo = 'assets/guia/rostro_cuerpo.png';

  // Alto / ancho de las imagenes (900 x 930)
  static const double proporcion = 930 / 900;

  // Centro de la cabeza dentro de la imagen: la cabeza gira sobre este punto
  static const Alignment centroCabeza = Alignment(0, -0.23);

  @override
  State<GuiaRostroAnimada> createState() => _GuiaRostroAnimadaState();
}

class _GuiaRostroAnimadaState extends State<GuiaRostroAnimada>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Avance del giro en cada ciclo (0 = de frente, 1 = gesto completo):
  // gira, se mantiene, vuelve al frente y espera antes de repetir.
  late Animation<double> _giro;

  // Giro maximo de la cabeza (radianes) y desplazamiento (fraccion del
  // ancho o del alto de la imagen)
  static const double _anguloLateral = 0.65;
  static const double _anguloVertical = 0.45;
  static const double _desplazamientoLateral = 0.15;
  static const double _desplazamientoVertical = 0.13;

  // Perspectiva: cuanto mas alto, mas se nota que un lado de la cabeza se
  // aleja y el otro se acerca
  static const double _perspectiva = 0.003;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2600),
      vsync: this,
    )..repeat();

    _giro = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 25),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 25,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 15),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Direccion del gesto en pantalla: x = -1 izquierda / 1 derecha,
  // y = -1 arriba / 1 abajo
  Offset get _direccion {
    final sentidoX = widget.espejo ? 1.0 : -1.0;
    switch (widget.gesto) {
      case 'izquierda':
        return Offset(-sentidoX, 0);
      case 'derecha':
        return Offset(sentidoX, 0);
      case 'arriba':
        return const Offset(0, -1);
      case 'abajo':
        return const Offset(0, 1);
      default:
        return Offset.zero;
    }
  }

  Widget _imagen(String ruta) => Image.asset(
        ruta,
        width: widget.ancho,
        height: widget.ancho * GuiaRostroAnimada.proporcion,
        fit: BoxFit.fill,
        // Si falta la imagen no se dibuja nada, para no romper la camara
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );

  @override
  Widget build(BuildContext context) {
    final alto = widget.ancho * GuiaRostroAnimada.proporcion;
    final cuerpo = _imagen(GuiaRostroAnimada.imagenCuerpo);
    final cabeza = _imagen(GuiaRostroAnimada.imagenCabeza);

    return IgnorePointer(
      child: SizedBox(
        width: widget.ancho,
        height: alto,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (widget.gesto == null) return _frontal(cuerpo, cabeza);
            return _conGesto(cuerpo, cabeza, alto);
          },
        ),
      ),
    );
  }

  // Foto frontal: silueta quieta con un brillo suave que sube y baja
  Widget _frontal(Widget cuerpo, Widget cabeza) {
    final t =
        Curves.easeInOutSine.transform((_controller.value * 2 - 1).abs());
    return Opacity(
      opacity: 0.55 + 0.25 * t,
      child: Stack(children: [cuerpo, cabeza]),
    );
  }

  // Foto de gesto: los hombros quedan fijos y la cabeza gira en 3D
  Widget _conGesto(Widget cuerpo, Widget cabeza, double alto) {
    final t = _giro.value;
    final dir = _direccion;

    // El lado de la cabeza hacia el que se gira se aleja (se ve mas chico)
    // y el opuesto se acerca:
    // - izquierda/derecha: rotacion en Y; un angulo positivo aleja el
    //   borde izquierdo, por eso se usa -dir.dx.
    // - arriba/abajo: rotacion en X; un angulo negativo aleja el borde
    //   superior (al mirar arriba la frente se va hacia atras y la
    //   barbilla se acerca), por eso se usa dir.dy.
    final matriz = Matrix4.identity()
      ..setEntry(3, 2, _perspectiva)
      ..translateByDouble(
          dir.dx * widget.ancho * _desplazamientoLateral * t,
          dir.dy * alto * _desplazamientoVertical * t,
          0,
          1)
      ..rotateY(-dir.dx * _anguloLateral * t)
      ..rotateX(dir.dy * _anguloVertical * t);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Opacity(opacity: 0.65, child: cuerpo),
        Transform(
          transform: matriz,
          alignment: GuiaRostroAnimada.centroCabeza,
          child: Opacity(opacity: 0.70 + 0.15 * t, child: cabeza),
        ),
        _flecha(dir, t, alto),
      ],
    );
  }

  // Flecha que avanza hacia el lado del gesto y se desvanece al volver.
  // Se ubica a la altura de la cabeza.
  Widget _flecha(Offset dir, double t, double alto) {
    final IconData icono;
    if (dir.dx < 0) {
      icono = Icons.keyboard_double_arrow_left_rounded;
    } else if (dir.dx > 0) {
      icono = Icons.keyboard_double_arrow_right_rounded;
    } else if (dir.dy < 0) {
      icono = Icons.keyboard_double_arrow_up_rounded;
    } else {
      icono = Icons.keyboard_double_arrow_down_rounded;
    }

    final centroY = GuiaRostroAnimada.centroCabeza.y * alto / 2;
    final distanciaX = widget.ancho * (0.34 + 0.06 * t);
    final distanciaY = alto * (0.31 + 0.05 * t);

    return Transform.translate(
      offset: Offset(dir.dx * distanciaX, centroY + dir.dy * distanciaY),
      child: Opacity(
        opacity: t,
        child: Icon(icono, size: widget.ancho * 0.16, color: widget.color),
      ),
    );
  }
}
