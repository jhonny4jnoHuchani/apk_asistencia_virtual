import 'package:flutter/material.dart';
import '../../models/horario.dart';
import '../horario_card.dart';

class HorarioList extends StatelessWidget {
  final List<Horario> horarios;
  final Future<void> Function() onRefresh;
  final void Function(int horarioId) onMarcarEntrada;
  final void Function(int horarioId) onMarcarSalida;

  const HorarioList({
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
        itemCount: horarios.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeader();
          }
          final horario = horarios[index - 1];
          return HorarioCard(
            horario: horario,
            onMarcarEntrada: () => onMarcarEntrada(horario.id),
            onMarcarSalida: () => onMarcarSalida(horario.id),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF5B67CA).withOpacity(0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF5B67CA).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF5B67CA).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.today_rounded,
              color: Color(0xFF5B67CA),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Horarios de Hoy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${horarios.length} clases programadas',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF636E72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
