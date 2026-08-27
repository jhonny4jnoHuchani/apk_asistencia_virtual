import 'package:flutter/material.dart';

class FaceOverlay extends StatelessWidget {
  final Color color;
  final bool isActive;
  final String message;

  const FaceOverlay({
    super.key,
    required this.color,
    required this.isActive,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 280,
        height: 350,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(140),
          border: Border.all(
            color: isActive ? color : Colors.white,
            width: 3,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            if (isActive) ...[
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
