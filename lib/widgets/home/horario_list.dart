import 'package:flutter/material.dart';
import '../../models/horario.dart';
import 'horario_card.dart';

class HorarioListView extends StatelessWidget {
  final List<Horario> horarios;
  final VoidCallback onRefresh;
  final Function(int, String, String) onMarcarEntrada;
  final Function(int, String, String) onMarcarSalida;

  const HorarioListView({
    super.key,
    required this.horarios,
    required this.onRefresh,
    required this.onMarcarEntrada,
    required this.onMarcarSalida,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: horarios.length,
        itemBuilder: (context, index) {
          final horario = horarios[index];
          return HorarioCard(
            horario: horario,
            onMarcarEntrada: () => onMarcarEntrada(
              horario.id,
              horario.horaInicio,
              horario.horaFin,
            ),
            onMarcarSalida: () => onMarcarSalida(
              horario.id,
              horario.horaInicio,
              horario.horaFin,
            ),
          );
        },
      ),
    );
  }
}
