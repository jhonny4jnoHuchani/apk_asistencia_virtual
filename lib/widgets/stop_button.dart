// widgets/stop_button.dart
import 'package:flutter/material.dart';

class StopButton extends StatelessWidget {
  final VoidCallback onPressed;
  final int capturasRealizadas;
  final int totalCapturas;
  final bool isPaused;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  const StopButton({
    super.key,
    required this.onPressed,
    required this.capturasRealizadas,
    required this.totalCapturas,
    this.isPaused = false,
    this.onPause,
    this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;
    final progress = capturasRealizadas / totalCapturas;
    final porcentaje = (progress * 100).toInt();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 10.0 : 16.0,
        vertical: isSmall ? 8.0 : 12.0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade50,
            Colors.red.shade100.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isSmall ? 12.0 : 16.0),
        border: Border.all(
          color: Colors.red.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 10.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de progreso
          Container(
            height: 4.0,
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(2.0),
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Colors.redAccent,
                          Colors.red,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
                Positioned(
                  right: 4.0,
                  top: -8.0,
                  child: Text(
                    '$porcentaje%',
                    style: TextStyle(
                      fontSize: 9.0,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8.0),
          // Contenido principal
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de estado
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: isSmall ? 36.0 : 44.0,
                    height: isSmall ? 36.0 : 44.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.shade50,
                      border: Border.all(
                        color: Colors.red.shade200,
                        width: 1.0,
                      ),
                    ),
                  ),
                  if (isPaused)
                    Icon(
                      Icons.pause_circle_outline,
                      color: Colors.orange.shade700,
                      size: isSmall ? 24.0 : 30.0,
                    )
                  else
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: child,
                        );
                      },
                      child: Icon(
                        Icons.camera,
                        color: Colors.red,
                        size: isSmall ? 20.0 : 24.0,
                      ),
                    ),
                  if (!isPaused)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12.0,
                        height: 12.0,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${capturasRealizadas % 10}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 12.0),

              // Información de captura
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isPaused ? 'Pausado' : 'Capturando...',
                    style: TextStyle(
                      color: isPaused
                          ? Colors.orange.shade700
                          : Colors.red.shade700,
                      fontSize: isSmall ? 11.0 : 13.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '$capturasRealizadas',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: isSmall ? 14.0 : 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ' / $totalCapturas',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: isSmall ? 10.0 : 12.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: isPaused
                              ? Colors.orange.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          '$porcentaje%',
                          style: TextStyle(
                            color: isPaused
                                ? Colors.orange.shade700
                                : Colors.red.shade700,
                            fontSize: 10.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(width: 12.0),

              // Botones de control
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón de pausa/reanudar
                  if (onPause != null && onResume != null)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isPaused ? onResume : onPause,
                        borderRadius: BorderRadius.circular(8.0),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmall ? 6.0 : 10.0,
                            vertical: isSmall ? 4.0 : 6.0,
                          ),
                          decoration: BoxDecoration(
                            color: isPaused
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: isPaused
                                  ? Colors.green.shade300
                                  : Colors.orange.shade300,
                              width: 1.0,
                            ),
                          ),
                          child: Icon(
                            isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            color: isPaused
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                            size: isSmall ? 18.0 : 22.0,
                          ),
                        ),
                      ),
                    ),

                  if (onPause != null && onResume != null)
                    const SizedBox(width: 4.0),

                  // Botón detener
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onPressed,
                      borderRadius: BorderRadius.circular(8.0),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmall ? 8.0 : 12.0,
                          vertical: isSmall ? 6.0 : 8.0,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.redAccent,
                              Colors.red,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8.0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.stop_rounded,
                              color: Colors.white,
                              size: 20.0,
                            ),
                            if (!isSmall) ...[
                              const SizedBox(width: 4.0),
                              const Text(
                                'Detener',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.0,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
