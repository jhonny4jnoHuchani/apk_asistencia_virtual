// ============================================
// GESTOS DEL MARCADO
// ============================================
// Gesto que se pide en la segunda foto del marcado (verificacion de vida).
// Se comparte entre el marcado real (home_screen.dart) y el modo practico
// de la guia, para que ambos pidan exactamente los mismos gestos.
// Antes estaban como metodos privados dentro de home_screen.dart.

String generarGestoAleatorio() {
  final gestos = ['arriba', 'abajo', 'izquierda', 'derecha'];
  final random = DateTime.now().millisecondsSinceEpoch % gestos.length;
  return gestos[random.toInt()];
}

String instruccionGesto(String gesto) {
  switch (gesto) {
    case 'arriba':
      return 'Por favor, mire hacia arriba';
    case 'abajo':
      return 'Por favor, mire hacia abajo';
    case 'izquierda':
      return 'Por favor, gire a la izquierda';
    case 'derecha':
      return 'Por favor, gire a la derecha';
    default:
      return 'Por favor, mire al frente';
  }
}
