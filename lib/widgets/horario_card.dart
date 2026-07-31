import 'package:flutter/material.dart';
import '../models/horario.dart';

class HorarioCard extends StatelessWidget {
  final Horario horario;
  final VoidCallback onMarcarEntrada;
  final VoidCallback onMarcarSalida;

  const HorarioCard({
    super.key,
    required this.horario,
    required this.onMarcarEntrada,
    required this.onMarcarSalida,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Materia y paralelo
            Row(
              children: [
                Expanded(
                  child: Text(
                    horario.materia,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getEstadoColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getEstadoColor(),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    horario.estadoMarcado,
                    style: TextStyle(
                      color: _getEstadoColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Información del horario
            Row(
              children: [
                // Hora
                _buildInfoItem(
                  icon: Icons.access_time,
                  text: '${horario.horaInicio} - ${horario.horaFin}',
                ),
                const SizedBox(width: 16),
                // Paralelo
                _buildInfoItem(
                  icon: Icons.group,
                  text: horario.paralelo,
                ),
              ],
            ),

            if (horario.ubicacion != null) ...[
              const SizedBox(height: 8),
              _buildInfoItem(
                icon: Icons.location_on,
                text: horario.ubicacion!,
              ),
            ],

            const SizedBox(height: 12),

            // Botones de acción
            if (!horario.estaCompletado)
              Row(
                children: [
                  if (!horario.yaMarcoEntrada)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onMarcarEntrada,
                        icon: const Icon(Icons.login),
                        label: const Text('Marcar Entrada'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  if (horario.yaMarcoEntrada && !horario.yaMarcoSalida)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onMarcarSalida,
                        icon: const Icon(Icons.logout),
                        label: const Text('Marcar Salida'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

            // Si está completado
            if (horario.estaCompletado)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Asistencia completada',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Item de información con icono
  Widget _buildInfoItem({required IconData icon, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // Color según estado
  Color _getEstadoColor() {
    if (horario.estaCompletado) return Colors.green;
    if (horario.yaMarcoEntrada && !horario.yaMarcoSalida) return Colors.orange;
    return Colors.blue;
  }
}