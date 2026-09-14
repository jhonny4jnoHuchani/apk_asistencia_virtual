import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../models/horario.dart';
import 'horario_card_extended.dart';

class HorarioListView extends StatelessWidget {
  final List<Horario> horarios;
  final VoidCallback onRefresh;
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
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: horarios.length,
        itemBuilder: (context, index) {
          final horario = horarios[index];
          return HorarioCardExtended(
            horario: horario,
            onMarcarEntrada: () => onMarcarEntrada(horario.id),
            onMarcarSalida: () => onMarcarSalida(horario.id),
          );
        },
      ),
    );
  }
}
