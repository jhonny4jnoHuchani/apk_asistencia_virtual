// widgets/permission_dialog.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionDialog extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onCancel;

  const PermissionDialog({
    super.key,
    required this.onOpenSettings,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Row(
        children: [
          Icon(Icons.camera_alt, color: Colors.orange),
          SizedBox(width: 12),
          Text('Permiso de cámara'),
        ],
      ),
      content: const Text(
        'El permiso de cámara fue denegado permanentemente. '
        'Por favor, ve a Configuración y habilita el permiso manualmente.',
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings),
          label: const Text('Abrir Configuración'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
