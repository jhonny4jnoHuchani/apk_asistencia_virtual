import 'package:flutter/material.dart';
import '../../models/horario.dart';
import '../horario_card.dart';

class HorarioListView extends StatelessWidget {
  final List<Horario> horarios;
  final Future<void> Function() onRefresh;
  final Function(int) onMarcarEntrada;
  final Function(int) onMarcarSalida;

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
      onRefresh: onRefresh,
      color: const Color(0xFF5B67CA),
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        itemCount: horarios.length,
        itemBuilder: (context, index) {
          final horario = horarios[index];
          return HorarioCard(
            horario: horario,
            onMarcarEntrada: () => onMarcarEntrada(horario.id),
            onMarcarSalida: () => onMarcarSalida(horario.id),
          );
        },
      ),
    );
  }
}
