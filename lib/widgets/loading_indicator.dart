import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final String? mensaje;

  const LoadingIndicator({
    super.key,
    this.mensaje,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (mensaje != null) ...[
            const SizedBox(height: 16),
            Text(
              mensaje!,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }
}