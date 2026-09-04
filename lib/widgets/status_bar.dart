// widgets/status_bar.dart
import 'package:flutter/material.dart';

class StatusBar extends StatelessWidget {
  final Map<String, dynamic> posicion;
  final bool isAutomaticMode;
  final bool isCapturing;
  final int capturasRealizadas;
  final int totalCapturas;

  const StatusBar({
    super.key,
    required this.posicion,
    required this.isAutomaticMode,
    required this.isCapturing,
    required this.capturasRealizadas,
    required this.totalCapturas,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;
    final isMedium = screenWidth < 400;

    // Tamaños adaptativos
    final marginV = isSmall ? 2 : (isMedium ? 3 : 4);
    final paddingH = isSmall ? 8 : (isMedium ? 10 : 12);
    final paddingV = isSmall ? 4 : (isMedium ? 6 : 8);
    final iconSize = isSmall ? 24 : (isMedium ? 28 : 32);
    final iconInner = isSmall ? 14 : (isMedium ? 16 : 18);
    final fontSize = isSmall ? 10 : (isMedium ? 11 : 12);
    final subFontSize = isSmall ? 9 : (isMedium ? 10 : 11);
    final spinnerSize = isSmall ? 12 : (isMedium ? 14 : 16);

    return Container(
      margin:
          EdgeInsets.symmetric(horizontal: 16, vertical: marginV.toDouble()),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: paddingH.toDouble(),
          vertical: paddingV.toDouble(),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isSmall ? 10 : 14),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: iconSize.toDouble(),
              height: iconSize.toDouble(),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade400,
                    Colors.deepPurple.shade700
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                posicion['icono'] as IconData,
                color: Colors.white,
                size: iconInner.toDouble(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.volume_up,
                        color: Colors.deepPurple[400],
                        size: fontSize - 2,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          posicion['nombre']!.toUpperCase(),
                          style: TextStyle(
                            color: Colors.deepPurple[700],
                            fontSize: fontSize.toDouble(),
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    isAutomaticMode
                        ? 'Capturando... $capturasRealizadas/$totalCapturas'
                        : 'Listo para iniciar',
                    style: TextStyle(
                      color: isAutomaticMode
                          ? Colors.deepPurple.shade600
                          : Colors.grey[600],
                      fontSize: subFontSize.toDouble(),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            if (isCapturing)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SizedBox(
                  width: spinnerSize.toDouble(),
                  height: spinnerSize.toDouble(),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.red.shade500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
