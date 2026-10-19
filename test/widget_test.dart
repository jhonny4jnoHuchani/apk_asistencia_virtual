import 'package:flutter_test/flutter_test.dart';
import 'package:mi_control_upea/models/horario.dart';
import 'package:mi_control_upea/models/marcado.dart';

void main() {
  group('Model Smoke Tests', () {
    test('Marcado parses properly and calculates diferenciaMinutos correctly',
        () {
      final marcado = Marcado(
        id: 1,
        horarioId: 10,
        fecha: DateTime(2026, 10, 19),
        hora: '08:20:00',
        tipo: 'entrada',
        materia: 'Anatomía',
        paralelo: 'A',
        estado: 'PENDIENTE',
        horaInicio: '08:00:00',
        horaFin: '10:00:00',
      );

      expect(marcado.materia, 'Anatomía');
      expect(marcado.diferenciaMinutos, 20);
    });

    test('Horario calculates yaMarcoEntrada and yaMarcoSalida correctly', () {
      final horario = Horario(
        id: 1,
        diaSemana: 'Lunes',
        horaInicio: '08:00',
        horaFin: '10:00',
        materia: 'Fisiología',
        paralelo: 'B',
        paraleloMateriaId: 10,
        ubicacionId: 5,
        yaMarcoEntrada: true,
        yaMarcoSalida: false,
      );

      expect(horario.yaMarcoEntrada, true);
      expect(horario.yaMarcoSalida, false);
      expect(horario.estaCompletado, false);
    });
  });
}
